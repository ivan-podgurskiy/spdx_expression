defmodule SpdxExpression.FuzzScriptTest do
  use ExUnit.Case, async: false

  @script "scripts/fuzz.exs"

  test "runs a deterministic mixed-input campaign and reports its replay parameters" do
    {output, status} = run_fuzz(["--runs", "40", "--seed", "101,202,303"])

    assert status == 0, output
    assert output =~ "Fuzz passed: runs=40 seed=101,202,303"
    assert output =~ "atoms_added=0"
    assert output =~ "arbitrary=10"
    assert output =~ "grammar=10"
    assert output =~ "mutated=10"
    assert output =~ "boundary=10"
  end

  test "rejects invalid fuzz arguments with usage and a non-zero exit" do
    {output, status} = run_fuzz(["--runs", "0"])

    assert status != 0
    assert output =~ "Usage: mix run scripts/fuzz.exs"
  end

  defp run_fuzz(arguments) do
    System.cmd("mix", ["run", @script | arguments],
      cd: File.cwd!(),
      env: [{"MIX_ENV", "dev"}],
      stderr_to_stdout: true
    )
  end
end
