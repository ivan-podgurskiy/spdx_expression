defmodule SpdxExpression.RobustnessTest do
  use ExUnit.Case, async: true

  alias SpdxExpression.Error

  test "accepts 65,536 bytes and rejects the 65,537th byte before parsing" do
    maximum_input = "LicenseRef-" <> String.duplicate("a", 65_536 - byte_size("LicenseRef-"))
    oversized_input = maximum_input <> "a"

    assert byte_size(maximum_input) == 65_536
    assert SpdxExpression.canonicalize(maximum_input) == {:ok, maximum_input}

    assert {:error, %Error{kind: :expression_too_long, offset: 65_536}} =
             SpdxExpression.canonicalize(oversized_input)

    refute SpdxExpression.valid?(oversized_input)
  end

  test "accepts 128 parenthesis levels and rejects the 129th level" do
    expression_128 = String.duplicate("(", 128) <> "mit" <> String.duplicate(")", 128)
    expression_129 = String.duplicate("(", 129) <> "mit" <> String.duplicate(")", 129)
    canonical_128 = String.duplicate("(", 128) <> "MIT" <> String.duplicate(")", 128)

    assert SpdxExpression.canonicalize(expression_128) == {:ok, canonical_128}

    assert {:error, %Error{kind: :expression_too_deep, offset: 128}} =
             SpdxExpression.canonicalize(expression_129)

    refute SpdxExpression.valid?(expression_129)
  end

  test "malformed and unsupported binaries never escape non-bang APIs" do
    malformed_inputs = [
      <<0xFF>>,
      <<0xFF, "MIT">>,
      <<"MIT", 0xFF>>,
      <<"MI", 0xFF, "T">>,
      <<0xC3>>,
      <<0xE2, 0x82>>,
      <<0, "MIT">>,
      <<1, "MIT">>,
      <<8, "MIT">>,
      <<31, "MIT">>,
      <<127, "MIT">>
    ]

    for input <- malformed_inputs do
      assert {:error, %Error{kind: :invalid_character}} = SpdxExpression.canonicalize(input)
      refute SpdxExpression.valid?(input)
    end
  end

  test "non-binary terms return invalid_type without escaping non-bang APIs" do
    non_binary_inputs = [
      nil,
      :mit,
      42,
      3.14,
      ["MIT"],
      %{license: "MIT"},
      {:license, "MIT"},
      fn -> "MIT" end,
      self(),
      make_ref()
    ]

    for input <- non_binary_inputs do
      assert {:error, %Error{kind: :invalid_type}} = SpdxExpression.canonicalize(input)
      refute SpdxExpression.valid?(input)
    end
  end
end
