defmodule SpdxExpression.AcceptanceTest do
  use ExUnit.Case, async: true

  alias SpdxExpression.Error

  test "canonicalizes the primary product example" do
    assert SpdxExpression.canonicalize("mit and (apache-2.0 or bsd-2-clause)") ==
             {:ok, "MIT AND (Apache-2.0 OR BSD-2-Clause)"}
  end

  test "preserves SPDX precedence and caller-provided grouping" do
    assert SpdxExpression.canonicalize("MIT OR Apache-2.0 AND BSD-2-Clause") ==
             {:ok, "MIT OR Apache-2.0 AND BSD-2-Clause"}

    assert SpdxExpression.canonicalize("(MIT OR Apache-2.0) AND BSD-2-Clause") ==
             {:ok, "(MIT OR Apache-2.0) AND BSD-2-Clause"}

    assert SpdxExpression.canonicalize("((mit))") == {:ok, "((MIT))"}
  end

  test "accepts WITH only for a simple license and current exception" do
    assert SpdxExpression.canonicalize("gpl-3.0-only with classpath-exception-2.0") ==
             {:ok, "GPL-3.0-only WITH Classpath-exception-2.0"}

    assert {:error, %Error{kind: :invalid_with_operand}} =
             SpdxExpression.canonicalize("(MIT) WITH Classpath-exception-2.0")
  end

  test "distinguishes unknown and deprecated licenses and exceptions" do
    assert {:error, %Error{kind: :unknown_license}} =
             SpdxExpression.canonicalize("Unknown-License")

    assert {:error, %Error{kind: :unknown_exception}} =
             SpdxExpression.canonicalize("MIT WITH Unknown-exception")

    assert {:error, %Error{kind: :deprecated_license}} =
             SpdxExpression.canonicalize("GPL-2.0")

    assert {:error, %Error{kind: :deprecated_exception}} =
             SpdxExpression.canonicalize("MIT WITH Nokia-Qt-exception-1.1")
  end

  test "supports local LicenseRef and rejects external DocumentRef" do
    assert SpdxExpression.canonicalize("licenseref-Acme.Internal") ==
             {:ok, "LicenseRef-Acme.Internal"}

    assert {:error, %Error{kind: :invalid_license_ref}} =
             SpdxExpression.canonicalize("LicenseRef-Acme_Internal")

    assert {:error, %Error{kind: :invalid_character}} =
             SpdxExpression.canonicalize("DocumentRef-External:LicenseRef-Acme")
  end

  test "implements the intentional plus suffix contract" do
    assert SpdxExpression.canonicalize("mit+") == {:ok, "MIT+"}

    assert {:error, %Error{kind: :invalid_plus_suffix}} =
             SpdxExpression.canonicalize("LicenseRef-Acme+")
  end

  test "canonicalization is idempotent across the core corpus" do
    corpus = [
      "mit",
      "MIT+",
      "LicenseRef-Acme.Internal",
      "GPL-3.0-only WITH Classpath-exception-2.0",
      "MIT OR Apache-2.0 AND BSD-2-Clause",
      "((mit))",
      "mit and (apache-2.0 or bsd-2-clause)"
    ]

    for input <- corpus do
      assert {:ok, canonical} = SpdxExpression.canonicalize(input)
      assert {:ok, ^canonical} = SpdxExpression.canonicalize(canonical)
    end
  end

  test "recognizes every active and deprecated SPDX 3.28.0 license" do
    for %{"licenseId" => id, "isDeprecatedLicenseId" => deprecated?} <-
          fixture("licenses.json", "licenses") do
      if deprecated? do
        assert {:error, %Error{kind: :deprecated_license}} =
                 SpdxExpression.canonicalize(id)
      else
        lowercase_id = String.downcase(id)
        assert {:ok, ^id} = SpdxExpression.canonicalize(lowercase_id)
      end
    end
  end

  test "recognizes every active and deprecated SPDX 3.28.0 exception" do
    for %{"licenseExceptionId" => id, "isDeprecatedLicenseId" => deprecated?} <-
          fixture("exceptions.json", "exceptions") do
      expression = "MIT WITH " <> String.downcase(id)

      if deprecated? do
        assert {:error, %Error{kind: :deprecated_exception}} =
                 SpdxExpression.canonicalize(expression)
      else
        canonical = "MIT WITH " <> id
        assert {:ok, ^canonical} = SpdxExpression.canonicalize(expression)
      end
    end
  end

  test "ordinary malformed binaries return errors and valid?/1 remains total" do
    invalid_inputs = [
      nil,
      "",
      "MIT AND",
      "(MIT",
      "MIT)",
      "MIT/Apache-2.0",
      "MIT\u00A0OR Apache-2.0",
      <<0xFF>>,
      String.duplicate("M", 65_537)
    ]

    for input <- invalid_inputs do
      assert {:error, %Error{}} = SpdxExpression.canonicalize(input)
      refute SpdxExpression.valid?(input)
    end
  end

  defp fixture(filename, key) do
    "priv/spdx/3.28.0"
    |> Path.join(filename)
    |> File.read!()
    |> Jason.decode!()
    |> Map.fetch!(key)
  end
end
