# Dependency-free canonicalization regression guard.
#
# Usage:
#
#   MIX_ENV=dev mix run scripts/benchmark.exs
#   MIX_ENV=dev mix run scripts/benchmark.exs --iterations 200000 --max-us 100.0
#
# This is a development/release check. Timing assertions are intentionally not
# part of ordinary CI or the Hex package.

defmodule SpdxExpression.Benchmark do
  @moduledoc false

  @representative "mit and (apache-2.0 or bsd-2-clause)"
  @expected {:ok, "MIT AND (Apache-2.0 OR BSD-2-Clause)"}
  @warmup_iterations 10_000
  @default_iterations 200_000
  @default_max_us 100.0
  @batch_count 20
  @usage "Usage: mix run scripts/benchmark.exs [--iterations POSITIVE_INTEGER] [--max-us NON_NEGATIVE_FLOAT]"

  def run(arguments) do
    case parse_arguments(arguments) do
      {:ok, iterations, max_us} ->
        measure(iterations, max_us)

      {:error, message} ->
        fail("#{message}\n#{@usage}")
    end
  end

  defp parse_arguments(arguments) do
    {options, positional, invalid} =
      OptionParser.parse(arguments, strict: [iterations: :integer, max_us: :float])

    with [] <- positional,
         [] <- invalid,
         iterations when is_integer(iterations) and iterations > 0 <-
           Keyword.get(options, :iterations, @default_iterations),
         max_us when is_float(max_us) and max_us >= 0.0 <-
           Keyword.get(options, :max_us, @default_max_us) do
      {:ok, iterations, max_us}
    else
      _invalid -> {:error, "invalid benchmark arguments"}
    end
  end

  defp measure(iterations, max_us) do
    :ok = run_calls(@warmup_iterations)

    batch_measurements =
      iterations
      |> batch_sizes()
      |> Enum.map(fn batch_size ->
        {elapsed_us, :ok} = :timer.tc(fn -> run_calls(batch_size) end)
        {elapsed_us, batch_size, elapsed_us / batch_size}
      end)

    total_us = Enum.sum(Enum.map(batch_measurements, &elem(&1, 0)))
    mean_us = total_us / iterations
    per_call_measurements = Enum.map(batch_measurements, &elem(&1, 2))
    min_batch_us = Enum.min(per_call_measurements)
    max_batch_us = Enum.max(per_call_measurements)

    if mean_us <= max_us do
      IO.puts(
        "Benchmark passed: iterations=#{iterations} warmup=#{@warmup_iterations} " <>
          "mean_us=#{decimal(mean_us)} min_batch_us=#{decimal(min_batch_us)} " <>
          "max_batch_us=#{decimal(max_batch_us)} guard_us=#{decimal(max_us)}"
      )
    else
      fail(
        "Benchmark guard failed: mean_us=#{decimal(mean_us)} exceeds max_us=#{decimal(max_us)} " <>
          "iterations=#{iterations}"
      )
    end
  end

  defp batch_sizes(iterations) do
    count = min(iterations, @batch_count)
    base_size = div(iterations, count)
    batches_with_extra_call = rem(iterations, count)

    Enum.map(1..count, fn batch ->
      base_size + if(batch <= batches_with_extra_call, do: 1, else: 0)
    end)
  end

  defp run_calls(0), do: :ok

  defp run_calls(remaining) do
    case SpdxExpression.canonicalize(@representative) do
      @expected -> run_calls(remaining - 1)
      other -> raise "unexpected canonicalization result: #{inspect(other)}"
    end
  end

  defp decimal(value), do: :erlang.float_to_binary(value, decimals: 3)

  defp fail(message) do
    IO.puts(:stderr, message)
    System.halt(1)
  end
end

SpdxExpression.Benchmark.run(System.argv())
