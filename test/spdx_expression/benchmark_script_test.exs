defmodule SpdxExpression.BenchmarkScriptTest do
  use ExUnit.Case, async: false

  @script "scripts/benchmark.exs"

  test "reports a measured mean below the requested guard" do
    {output, status} = run_benchmark(["--iterations", "10000", "--max-us", "100.0"])

    assert status == 0, output
    assert output =~ "Benchmark passed: iterations=10000"
    assert [_, mean] = Regex.run(~r/mean_us=([0-9]+\.[0-9]+)/, output)
    assert String.to_float(mean) > 0.0
  end

  test "returns a non-zero exit when the measured mean exceeds the guard" do
    {output, status} = run_benchmark(["--iterations", "1000", "--max-us", "0.0"])

    assert status != 0
    assert output =~ "Benchmark guard failed:"
    assert output =~ "max_us=0.000"
  end

  defp run_benchmark(arguments) do
    System.cmd("mix", ["run", @script | arguments],
      cd: File.cwd!(),
      env: [{"MIX_ENV", "dev"}],
      stderr_to_stdout: true
    )
  end
end
