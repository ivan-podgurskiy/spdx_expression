# Reproducible hostile-input campaign for the non-bang public API.
#
# Usage:
#
#   MIX_ENV=dev mix run scripts/fuzz.exs
#   MIX_ENV=dev mix run scripts/fuzz.exs --runs 1000000 --seed 101,202,303
#
# This is a development/release check. It is not part of ordinary CI or the
# Hex package.

defmodule SpdxExpression.Fuzz do
  @moduledoc false

  alias SpdxExpression.Error

  @default_runs 1_000_000
  @default_seed {101, 202, 303}
  @usage "Usage: mix run scripts/fuzz.exs [--runs POSITIVE_INTEGER] [--seed A,B,C]"

  @grammar_tokens [
    "MIT",
    "Apache-2.0",
    "BSD-3-Clause",
    "LicenseRef-Acme",
    "Classpath-exception-2.0",
    "AND",
    "or",
    "wItH",
    "(",
    ")",
    "+",
    "_",
    ":",
    "Unknown-License"
  ]

  @valid_expressions [
    "MIT",
    "mit+",
    "LicenseRef-Acme.Internal",
    "GPL-3.0-only WITH Classpath-exception-2.0",
    "MIT OR Apache-2.0 AND BSD-2-Clause",
    "(MIT OR Apache-2.0) AND BSD-2-Clause",
    "mit and (apache-2.0 or bsd-2-clause)"
  ]

  def run(arguments) do
    case parse_arguments(arguments) do
      {:ok, runs, seed} -> run_campaign(runs, seed)
      {:error, message} -> fail("#{message}\n#{@usage}")
    end
  end

  defp parse_arguments(arguments) do
    {options, positional, invalid} =
      OptionParser.parse(arguments, strict: [runs: :integer, seed: :string])

    with [] <- positional,
         [] <- invalid,
         runs when is_integer(runs) and runs > 0 <- Keyword.get(options, :runs, @default_runs),
         {:ok, seed} <- parse_seed(Keyword.get(options, :seed, seed_string(@default_seed))) do
      {:ok, runs, seed}
    else
      _invalid -> {:error, "invalid fuzz arguments"}
    end
  end

  defp parse_seed(seed) do
    case String.split(seed, ",") do
      [first, second, third] ->
        with {a, ""} when a > 0 <- Integer.parse(first),
             {b, ""} when b > 0 <- Integer.parse(second),
             {c, ""} when c > 0 <- Integer.parse(third) do
          {:ok, {a, b, c}}
        else
          _invalid -> {:error, :invalid_seed}
        end

      _invalid ->
        {:error, :invalid_seed}
    end
  end

  defp run_campaign(runs, seed) do
    warmup_seed = :rand.seed_s(:exsss, {11, 22, 33})
    {_warmup_state, _warmup_counts} = execute(100, warmup_seed, false, nil)
    :erlang.garbage_collect()

    atom_count_before = :erlang.system_info(:atom_count)
    state = :rand.seed_s(:exsss, seed)
    started_at = System.monotonic_time()
    {_state, counts} = execute(runs, state, true, seed)
    elapsed_ms = elapsed_milliseconds(started_at)

    :erlang.garbage_collect()
    atom_count_after = :erlang.system_info(:atom_count)
    atoms_added = atom_count_after - atom_count_before

    if atoms_added == 0 do
      IO.puts(
        "Fuzz passed: runs=#{runs} seed=#{seed_string(seed)} elapsed_ms=#{elapsed_ms} " <>
          "atoms_added=0 classes=#{format_counts(counts)}"
      )
    else
      fail("atom table grew by #{atoms_added} entries")
    end
  end

  defp execute(runs, state, halt_on_failure?, replay_seed) do
    counts = %{arbitrary: 0, grammar: 0, mutated: 0, boundary: 0}
    execute(1, runs, state, counts, halt_on_failure?, replay_seed)
  end

  defp execute(iteration, runs, state, counts, _halt_on_failure?, _replay_seed)
       when iteration > runs,
       do: {state, counts}

  defp execute(iteration, runs, state, counts, halt_on_failure?, replay_seed) do
    class = input_class(iteration)
    {input, next_state} = generate_input(class, iteration, state)
    next_counts = Map.update!(counts, class, &(&1 + 1))

    case verify_input(input) do
      :ok ->
        execute(iteration + 1, runs, next_state, next_counts, halt_on_failure?, replay_seed)

      {:error, reason} when halt_on_failure? ->
        fuzz_failure(iteration, class, input, reason, replay_seed)

      {:error, _reason} ->
        execute(iteration + 1, runs, next_state, next_counts, halt_on_failure?, replay_seed)
    end
  end

  defp input_class(iteration) do
    case rem(iteration - 1, 4) do
      0 -> :arbitrary
      1 -> :grammar
      2 -> :mutated
      3 -> :boundary
    end
  end

  defp generate_input(:arbitrary, _iteration, state) do
    {length, next_state} = uniform(1_025, state)
    :rand.bytes_s(length - 1, next_state)
  end

  defp generate_input(:grammar, _iteration, state) do
    {token_count, next_state} = uniform(24, state)
    generate_tokens(token_count, next_state, [])
  end

  defp generate_input(:mutated, _iteration, state) do
    {input, next_state} = choose(@valid_expressions, state)
    {mutation, next_state} = uniform(3, next_state)
    mutate(input, mutation, next_state)
  end

  defp generate_input(:boundary, iteration, state) when rem(iteration, 10_000) == 0 do
    maximum_license_ref =
      "LicenseRef-" <> String.duplicate("a", 65_536 - byte_size("LicenseRef-"))

    choose(
      [
        maximum_license_ref,
        maximum_license_ref <> "a",
        String.duplicate("(", 128) <> "MIT" <> String.duplicate(")", 128),
        String.duplicate("(", 129) <> "MIT" <> String.duplicate(")", 129)
      ],
      state
    )
  end

  defp generate_input(:boundary, _iteration, state) do
    {mode, next_state} = uniform(4, state)

    case mode do
      1 ->
        {depth, final_state} = uniform(141, next_state)
        depth = depth - 1
        {String.duplicate("(", depth) <> "MIT" <> String.duplicate(")", depth), final_state}

      2 ->
        {length, final_state} = uniform(1_025, next_state)
        {"LicenseRef-" <> String.duplicate("a", length - 1), final_state}

      3 ->
        choose([<<0xFF>>, <<0xC3>>, <<0xE2, 0x82>>, <<0, "MIT">>, <<127, "MIT">>], next_state)

      4 ->
        choose(["", "()", "MIT AND", "MIT++", "MIT WITH WITH", "((MIT)+)"], next_state)
    end
  end

  defp generate_tokens(0, state, tokens), do: {tokens |> Enum.reverse() |> Enum.join(" "), state}

  defp generate_tokens(remaining, state, tokens) do
    {token, next_state} = choose(@grammar_tokens, state)
    generate_tokens(remaining - 1, next_state, [token | tokens])
  end

  defp mutate(input, 1, state) do
    {position, next_state} = uniform(byte_size(input) + 1, state)
    {byte, final_state} = uniform(256, next_state)
    position = position - 1

    mutated =
      binary_part(input, 0, position) <>
        <<byte - 1>> <> binary_part(input, position, byte_size(input) - position)

    {mutated, final_state}
  end

  defp mutate(input, 2, state) do
    {position, next_state} = uniform(byte_size(input), state)
    position = position - 1

    mutated =
      binary_part(input, 0, position) <>
        binary_part(input, position + 1, byte_size(input) - position - 1)

    {mutated, next_state}
  end

  defp mutate(input, 3, state) do
    {position, next_state} = uniform(byte_size(input), state)
    {byte, final_state} = uniform(256, next_state)
    position = position - 1

    mutated =
      binary_part(input, 0, position) <>
        <<byte - 1>> <> binary_part(input, position + 1, byte_size(input) - position - 1)

    {mutated, final_state}
  end

  defp verify_input(input) do
    result = SpdxExpression.canonicalize(input)
    valid? = SpdxExpression.valid?(input)

    case result do
      {:ok, canonical} when is_binary(canonical) ->
        cond do
          not valid? -> {:error, {:valid_disagrees, result}}
          SpdxExpression.canonicalize(canonical) != {:ok, canonical} -> {:error, :not_idempotent}
          true -> :ok
        end

      {:error, %Error{}} ->
        if valid?, do: {:error, {:valid_disagrees, result}}, else: :ok

      other ->
        {:error, {:unexpected_result, other}}
    end
  rescue
    exception -> {:error, {:exception, exception, __STACKTRACE__}}
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp choose(values, state) do
    {index, next_state} = uniform(length(values), state)
    {Enum.at(values, index - 1), next_state}
  end

  defp uniform(maximum, state), do: :rand.uniform_s(maximum, state)

  defp elapsed_milliseconds(started_at) do
    System.monotonic_time()
    |> Kernel.-(started_at)
    |> System.convert_time_unit(:native, :millisecond)
  end

  defp seed_string({a, b, c}), do: "#{a},#{b},#{c}"

  defp format_counts(counts) do
    "arbitrary=#{counts.arbitrary},grammar=#{counts.grammar}," <>
      "mutated=#{counts.mutated},boundary=#{counts.boundary}"
  end

  defp fuzz_failure(iteration, class, input, reason, replay_seed) do
    IO.puts(
      :stderr,
      "Fuzz failed: iteration=#{iteration} class=#{class} reason=#{inspect(reason)}"
    )

    IO.puts(:stderr, "input_base64=#{Base.encode64(input)}")

    fail(
      "replay: MIX_ENV=dev mix run scripts/fuzz.exs --runs #{iteration} " <>
        "--seed #{seed_string(replay_seed)}"
    )
  end

  defp fail(message) do
    IO.puts(:stderr, message)
    System.halt(1)
  end
end

SpdxExpression.Fuzz.run(System.argv())
