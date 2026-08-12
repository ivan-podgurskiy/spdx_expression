defmodule SpdxExpression.CompatibilityTest do
  use ExUnit.Case, async: true

  alias SpdxExpression.Error

  @fixture_path "test/fixtures/license_expression_compatibility.json"
  @difference_labels ~w(
    deprecated_identifiers
    empty_license_ref
    spdx_data_version
    unicode_whitespace
    with_operand_validation
  )

  setup_all do
    corpus =
      @fixture_path
      |> File.read!()
      |> Jason.decode!()

    {:ok, corpus: corpus, cases: Map.fetch!(corpus, "cases")}
  end

  test "pins the corpus sources and oracle versions", %{corpus: corpus, cases: cases} do
    assert corpus["schema_version"] == 1
    assert corpus["spdx_license_list_version"] == "3.28.0"

    assert corpus["packaging_26_0"] == %{
             "commit" => "3b77a26f5a27473ad3b08194d773f325d018a2d0",
             "spdx_license_list_version" => "3.27.0",
             "version" => "26.0"
           }

    assert length(cases) >= 60
    assert Enum.all?(cases, &is_binary(&1["id"]))
    assert length(Enum.uniq_by(cases, & &1["id"])) == length(cases)
  end

  test "matches packaging 26.0 for every shared corpus case", %{cases: cases} do
    shared_cases = Enum.reject(cases, &Map.has_key?(&1, "difference"))

    assert length(shared_cases) >= 50

    for fixture <- shared_cases do
      assert_project_result(fixture)

      assert comparable_project_result(fixture["project"]) == fixture["packaging_26_0"],
             "unexpected oracle difference in #{fixture["id"]}"
    end
  end

  test "rejects deprecated identifiers while packaging accepts them", %{cases: cases} do
    assert_difference(cases, "deprecated_identifiers")
  end

  test "uses SPDX 3.28.0 identifiers newer than packaging's 3.27.0 data", %{cases: cases} do
    assert_difference(cases, "spdx_data_version")
  end

  test "requires a simple license on the left side of WITH", %{cases: cases} do
    assert_difference(cases, "with_operand_validation")
  end

  test "rejects an empty LicenseRef suffix", %{cases: cases} do
    assert_difference(cases, "empty_license_ref")
  end

  test "accepts only ASCII whitespace even though packaging splits Unicode whitespace", %{
    cases: cases
  } do
    assert_difference(cases, "unicode_whitespace")
  end

  test "has one named regression test for every intentional oracle difference", %{cases: cases} do
    actual_labels =
      cases
      |> Enum.flat_map(&(Map.take(&1, ["difference"]) |> Map.values()))
      |> Enum.uniq()
      |> Enum.sort()

    assert actual_labels == Enum.sort(@difference_labels)
  end

  test "canonicalization is idempotent across every successful project fixture", %{cases: cases} do
    for %{"project" => %{"status" => "ok", "canonical" => canonical}} <- cases do
      assert SpdxExpression.canonicalize(canonical) == {:ok, canonical}
    end
  end

  test "keeps the pinned Python oracle in an explicitly invoked development script" do
    script = File.read!("scripts/differential_check.exs")
    workflow = File.read!(".github/workflows/ci.yml")

    assert script =~ ~s(@packaging_version "26.0")
    assert script =~ @fixture_path
    assert script =~ ~s("--update")
    refute workflow =~ "differential_check"
  end

  defp assert_difference(cases, label) do
    difference_cases = Enum.filter(cases, &(&1["difference"] == label))

    assert difference_cases != [], "missing fixtures for #{label}"

    for fixture <- difference_cases do
      assert_project_result(fixture)

      refute comparable_project_result(fixture["project"]) == fixture["packaging_26_0"],
             "#{fixture["id"]} is labeled as a difference but outcomes match"
    end
  end

  defp assert_project_result(%{"id" => id, "input" => input, "project" => expected}) do
    case expected do
      %{"status" => "ok", "canonical" => canonical} ->
        assert SpdxExpression.canonicalize(input) == {:ok, canonical}, id

      %{"status" => "error", "kind" => kind} ->
        assert {:error, %Error{kind: actual_kind}} = SpdxExpression.canonicalize(input), id
        assert Atom.to_string(actual_kind) == kind, id
    end
  end

  defp comparable_project_result(%{"status" => "ok", "canonical" => canonical}),
    do: %{"status" => "ok", "canonical" => canonical}

  defp comparable_project_result(%{"status" => "error"}), do: %{"status" => "error"}
end
