defmodule SpdxExpressionTest do
  use ExUnit.Case, async: true

  doctest SpdxExpression

  test "reports the embedded SPDX License List version" do
    assert SpdxExpression.license_list_version() == "3.28.0"
  end
end
