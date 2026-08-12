defmodule SpdxExpression.ParserTest do
  use ExUnit.Case, async: true

  alias SpdxExpression.Error
  alias SpdxExpression.Parser
  alias SpdxExpression.Tokenizer

  test "applies AND more strongly than OR" do
    assert parse!("MIT OR Apache-2.0 AND BSD-2-Clause") ==
             {:or, {:license, "MIT"},
              {:and, {:license, "Apache-2.0"}, {:license, "BSD-2-Clause"}}}
  end

  test "preserves required and redundant grouping nodes" do
    assert parse!("(MIT OR Apache-2.0) AND BSD-2-Clause") ==
             {:and, {:group, {:or, {:license, "MIT"}, {:license, "Apache-2.0"}}},
              {:license, "BSD-2-Clause"}}

    assert parse!("((MIT))") == {:group, {:group, {:license, "MIT"}}}
  end

  test "associates repeated AND and OR operators to the left" do
    assert parse!("MIT AND Apache-2.0 AND BSD-2-Clause") ==
             {:and, {:and, {:license, "MIT"}, {:license, "Apache-2.0"}},
              {:license, "BSD-2-Clause"}}

    assert parse!("MIT OR Apache-2.0 OR BSD-2-Clause") ==
             {:or, {:or, {:license, "MIT"}, {:license, "Apache-2.0"}}, {:license, "BSD-2-Clause"}}
  end

  test "attaches a current exception to a simple license" do
    assert parse!("GPL-3.0-only WITH Classpath-exception-2.0") ==
             {:with, {:license, "GPL-3.0-only"}, "Classpath-exception-2.0"}
  end

  test "resolves unknown and deprecated identifiers in their grammar positions" do
    assert_error("Unknown-License", :unknown_license, 0)
    assert_error("GPL-2.0", :deprecated_license, 0)
    assert_error("MIT WITH Unknown-exception", :unknown_exception, 9)
    assert_error("MIT WITH Nokia-Qt-exception-1.1", :deprecated_exception, 9)
  end

  test "reports missing and unexpected operands" do
    assert_error("MIT AND", :unexpected_end, 7)
    assert_error("OR MIT", :unexpected_token, 0)
    assert_error("()", :unexpected_token, 1)
    assert_error("MIT Apache-2.0", :unexpected_token, 4)
  end

  test "reports missing and extra parentheses" do
    assert_error("(MIT", :unbalanced_parenthesis, 0)
    assert_error("MIT)", :unbalanced_parenthesis, 3)
    assert_error("(MIT))", :unbalanced_parenthesis, 5)
  end

  test "rejects WITH on groups, missing exceptions, and repeated WITH" do
    assert_error("(MIT) WITH Classpath-exception-2.0", :invalid_with_operand, 6)
    assert_error("MIT WITH", :unexpected_end, 8)
    assert_error("MIT WITH (Classpath-exception-2.0)", :invalid_with_operand, 9)

    assert_error(
      "MIT WITH Classpath-exception-2.0 WITH Classpath-exception-2.0",
      :invalid_with_operand,
      33
    )
  end

  test "accepts one plus after any recognized SPDX license" do
    assert parse!("MIT+") == {:license, "MIT+"}

    assert parse!("GPL-3.0-only+ WITH Classpath-exception-2.0") ==
             {:with, {:license, "GPL-3.0-only+"}, "Classpath-exception-2.0"}
  end

  test "rejects misplaced and repeated plus suffixes" do
    assert_error("LicenseRef-Acme+", :invalid_plus_suffix, 15)
    assert_error("+MIT", :invalid_plus_suffix, 0)
    assert_error("MIT +", :invalid_plus_suffix, 4)
    assert_error("MIT++", :invalid_plus_suffix, 4)
    assert_error("(MIT)+", :invalid_plus_suffix, 5)
    assert_error("MIT WITH Classpath-exception-2.0+", :invalid_plus_suffix, 32)
  end

  test "reports tokens that cannot close a parenthesized expression" do
    assert_error("((MIT)+)", :invalid_plus_suffix, 6)
    assert_error("(MIT Apache-2.0)", :unexpected_token, 5)
  end

  test "reports an unknown plus-suffixed base as an unknown license" do
    assert_error("Unknown-License+", :unknown_license, 0)
  end

  test "accepts 128 group levels and rejects the 129th" do
    input_128 = String.duplicate("(", 128) <> "MIT" <> String.duplicate(")", 128)
    input_129 = String.duplicate("(", 129) <> "MIT" <> String.duplicate(")", 129)

    assert {:ok, _ast} = parse(input_128)
    assert_error(input_129, :expression_too_deep, 128)
  end

  defp parse!(input) do
    assert {:ok, ast} = parse(input)
    ast
  end

  defp parse(input) do
    assert {:ok, tokens} = Tokenizer.tokenize(input)
    Parser.parse(tokens, byte_size(input))
  end

  defp assert_error(input, kind, offset) do
    assert {:error, %Error{kind: ^kind, offset: ^offset}} = parse(input)
  end
end
