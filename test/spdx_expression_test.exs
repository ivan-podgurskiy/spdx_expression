defmodule SpdxExpressionTest do
  use ExUnit.Case, async: true

  doctest SpdxExpression

  test "reports the embedded SPDX License List version" do
    assert SpdxExpression.license_list_version() == "3.28.0"
  end

  test "canonicalizes identifiers, operators, whitespace, and parentheses" do
    assert SpdxExpression.canonicalize(" mit and (apache-2.0 or bsd-2-clause) ") ==
             {:ok, "MIT AND (Apache-2.0 OR BSD-2-Clause)"}
  end

  test "preserves precedence without adding parentheses" do
    assert SpdxExpression.canonicalize("MIT OR Apache-2.0 AND BSD-2-Clause") ==
             {:ok, "MIT OR Apache-2.0 AND BSD-2-Clause"}

    assert SpdxExpression.canonicalize("(MIT OR Apache-2.0) AND BSD-2-Clause") ==
             {:ok, "(MIT OR Apache-2.0) AND BSD-2-Clause"}
  end

  test "canonicalizes LicenseRef prefix while preserving its suffix" do
    assert SpdxExpression.canonicalize("licenseref-Acme.Internal") ==
             {:ok, "LicenseRef-Acme.Internal"}
  end

  test "returns structured errors for invalid types and empty input" do
    assert {:error, %SpdxExpression.Error{kind: :invalid_type, offset: nil}} =
             SpdxExpression.canonicalize(%{secret: "not inspected"})

    for input <- ["", " \t\r\n"] do
      assert {:error, %SpdxExpression.Error{kind: :empty_expression, offset: 0}} =
               SpdxExpression.canonicalize(input)
    end
  end

  test "checks the byte length before tokenization" do
    allowed = String.duplicate("M", 65_536)
    oversized = allowed <> "M"

    assert {:error, %SpdxExpression.Error{kind: :unknown_license}} =
             SpdxExpression.canonicalize(allowed)

    assert {:error, %SpdxExpression.Error{kind: :expression_too_long, offset: 65_536}} =
             SpdxExpression.canonicalize(oversized)
  end

  test "bang API returns a string or raises the returned error" do
    assert SpdxExpression.canonicalize!("mit") == "MIT"

    assert_raise SpdxExpression.Error,
                 "unknown SPDX license identifier \"Unknown-License\" at byte 0",
                 fn -> SpdxExpression.canonicalize!("Unknown-License") end
  end

  test "valid?/1 is total for ordinary invalid input" do
    assert SpdxExpression.valid?("MIT OR Apache-2.0")

    for input <- [nil, "", "Unknown-License", <<0xFF>>, String.duplicate("M", 65_537)] do
      refute SpdxExpression.valid?(input)
    end
  end
end
