# Differential check against Python packaging's PEP 639 canonicalizer.
#
# Usage:
#
#   python3 -m pip install "packaging==26.0"
#   mix run scripts/differential_check.exs
#
# This is dev-only and intentionally not wired into CI or the Hex package.

defmodule SpdxExpression.DifferentialCheck do
  @moduledoc false

  @packaging_version "26.0"
  @fixture_path "test/fixtures/license_expression_compatibility.json"

  @python ~S'''
  import base64
  import json
  import sys

  try:
      import packaging
      from packaging.licenses import canonicalize_license_expression
  except ModuleNotFoundError:
      print(json.dumps({"status": "skip", "reason": "packaging is not installed"}))
      sys.exit(0)

  required_version = sys.argv[1]
  if packaging.__version__ != required_version:
      print(json.dumps({
          "status": "wrong_version",
          "actual": packaging.__version__,
          "required": required_version,
      }))
      sys.exit(0)

  inputs = json.loads(base64.b64decode(sys.argv[2]).decode("utf-8"))
  outcomes = []

  for expression in inputs:
      try:
          canonical = canonicalize_license_expression(expression)
          outcomes.append({"status": "ok", "canonical": canonical})
      except Exception:
          outcomes.append({"status": "error"})

  print(json.dumps({"status": "ok", "outcomes": outcomes}))
  '''

  def run do
    with python when is_binary(python) <- System.find_executable("python3"),
         {:ok, corpus} <- read_corpus(),
         :ok <- verify_python(python, corpus),
         :ok <- verify_project(corpus) do
      report_success(corpus)
    else
      nil ->
        skip("python3 is not installed")

      {:skip, reason} ->
        skip(reason)

      {:error, message} ->
        fail(message)
    end
  end

  defp read_corpus do
    with {:ok, contents} <- File.read(@fixture_path),
         {:ok, corpus} <- Jason.decode(contents) do
      {:ok, corpus}
    else
      {:error, reason} -> {:error, "cannot read compatibility corpus: #{inspect(reason)}"}
    end
  end

  defp verify_python(python, %{"cases" => cases}) do
    inputs = Enum.map(cases, &Map.fetch!(&1, "input"))
    encoded_inputs = inputs |> Jason.encode!() |> Base.encode64()

    case System.cmd(python, ["-c", @python, @packaging_version, encoded_inputs]) do
      {output, 0} -> verify_python_output(output, cases)
      {output, status} -> {:error, "Python oracle exited with status #{status}: #{output}"}
    end
  end

  defp verify_python_output(output, cases) do
    case Jason.decode(output) do
      {:ok, %{"status" => "skip", "reason" => reason}} ->
        {:skip, reason <> ~s(; install it with: python3 -m pip install "packaging==26.0")}

      {:ok, %{"status" => "wrong_version", "actual" => actual}} ->
        {:error,
         "Python packaging #{actual} is installed; expected #{@packaging_version}. " <>
           ~s(Install it with: python3 -m pip install "packaging==26.0")}

      {:ok, %{"status" => "ok", "outcomes" => outcomes}} ->
        compare_outcomes(cases, outcomes, "packaging_26_0")

      {:ok, result} ->
        {:error, "unexpected Python oracle response: #{inspect(result)}"}

      {:error, reason} ->
        {:error, "invalid Python oracle response: #{inspect(reason)}; output: #{output}"}
    end
  end

  defp verify_project(%{"cases" => cases}) do
    outcomes = Enum.map(cases, &project_outcome/1)
    compare_outcomes(cases, outcomes, "project")
  end

  defp project_outcome(%{"input" => input}) do
    case SpdxExpression.canonicalize(input) do
      {:ok, canonical} ->
        %{"status" => "ok", "canonical" => canonical}

      {:error, error} ->
        %{"status" => "error", "kind" => Atom.to_string(error.kind)}
    end
  end

  defp compare_outcomes(cases, outcomes, expected_key) when length(cases) == length(outcomes) do
    cases
    |> Enum.zip(outcomes)
    |> Enum.find_value(:ok, fn {fixture, actual} ->
      expected = Map.fetch!(fixture, expected_key)

      if actual == expected do
        false
      else
        {:error,
         "#{expected_key} mismatch in #{fixture["id"]}: " <>
           "expected #{inspect(expected)}, got #{inspect(actual)}"}
      end
    end)
  end

  defp compare_outcomes(cases, outcomes, expected_key) do
    {:error,
     "#{expected_key} returned #{length(outcomes)} outcomes for #{length(cases)} corpus cases"}
  end

  defp report_success(%{"cases" => cases}) do
    difference_count = Enum.count(cases, &Map.has_key?(&1, "difference"))
    shared_count = length(cases) - difference_count

    IO.puts(
      "Differential check passed: #{shared_count} shared cases and " <>
        "#{difference_count} named intentional differences."
    )
  end

  defp skip(reason) do
    IO.puts("Skipping differential check: #{reason}.")
  end

  defp fail(message) do
    IO.puts(:stderr, "Differential check failed: #{message}")
    System.halt(1)
  end
end

SpdxExpression.DifferentialCheck.run()
