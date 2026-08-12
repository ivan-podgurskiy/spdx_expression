defmodule SpdxExpression.RegistryTest do
  use ExUnit.Case, async: true

  alias SpdxExpression.Error
  alias SpdxExpression.Registry

  test "resolves current licenses case-insensitively" do
    assert Registry.resolve_license("mit", 4) == {:ok, "MIT"}
    assert Registry.resolve_license("aPaChE-2.0", 0) == {:ok, "Apache-2.0"}
  end

  test "canonicalizes the LicenseRef prefix and preserves its suffix" do
    assert Registry.resolve_license("licenseref-Acme.Internal", 0) ==
             {:ok, "LicenseRef-Acme.Internal"}
  end

  test "rejects malformed LicenseRef identifiers" do
    for value <- ["LicenseRef-", "LicenseRef-Acme_Internal"] do
      assert {:error, %Error{kind: :invalid_license_ref, token: ^value, offset: 2}} =
               Registry.resolve_license(value, 2)
    end
  end

  test "distinguishes deprecated and unknown licenses" do
    assert {:error, %Error{kind: :deprecated_license, offset: 0}} =
             Registry.resolve_license("GPL-2.0", 0)

    assert {:error, %Error{kind: :unknown_license, token: "Unknown-License", offset: 7}} =
             Registry.resolve_license("Unknown-License", 7)
  end

  test "resolves current exceptions case-insensitively" do
    assert Registry.resolve_exception("classpath-exception-2.0", 9) ==
             {:ok, "Classpath-exception-2.0"}
  end

  test "distinguishes deprecated and unknown exceptions" do
    assert {:error, %Error{kind: :deprecated_exception, offset: 0}} =
             Registry.resolve_exception("Nokia-Qt-exception-1.1", 0)

    assert {:error, %Error{kind: :unknown_exception, token: "Unknown-exception", offset: 9}} =
             Registry.resolve_exception("Unknown-exception", 9)
  end
end
