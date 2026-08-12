defmodule SpdxExpression.ErrorTest do
  use ExUnit.Case, async: true

  alias SpdxExpression.Error

  test "builds a deterministic identifier error" do
    error = Error.new(:unknown_license, token: "Unknown-License", offset: 7)

    assert error.kind == :unknown_license
    assert error.token == "Unknown-License"
    assert error.offset == 7
    assert error.suggestion == nil

    assert Exception.message(error) ==
             "unknown SPDX license identifier \"Unknown-License\" at byte 7"
  end

  test "invalid type does not inspect the supplied value" do
    error = Error.new(:invalid_type)

    assert error.kind == :invalid_type
    assert error.token == nil
    assert error.offset == nil
    assert error.message == "expected a binary SPDX license expression"
  end

  test "empty expressions use byte zero" do
    error = Error.new(:empty_expression, offset: 0)

    assert error.offset == 0
    assert error.message == "SPDX license expression is empty at byte 0"
  end

  test "exception/1 delegates to the stable constructor" do
    error = Error.exception(kind: :invalid_plus_suffix, token: "+", offset: 3)

    assert error == Error.new(:invalid_plus_suffix, token: "+", offset: 3)
  end

  test "supports every public error kind" do
    kinds = [
      :invalid_type,
      :empty_expression,
      :invalid_character,
      :unexpected_token,
      :unexpected_end,
      :unbalanced_parenthesis,
      :unknown_license,
      :unknown_exception,
      :deprecated_license,
      :deprecated_exception,
      :invalid_license_ref,
      :invalid_plus_suffix,
      :invalid_with_operand,
      :expression_too_long,
      :expression_too_deep
    ]

    for kind <- kinds do
      assert %Error{kind: ^kind, message: message} =
               Error.new(kind, token: "token", offset: 1)

      assert is_binary(message)
      assert message != ""
    end
  end
end
