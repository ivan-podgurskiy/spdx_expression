defmodule SpdxExpression.PropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias SpdxExpression.Test.ExpressionGenerator

  alias SpdxExpression.Canonicalizer
  alias SpdxExpression.Parser
  alias SpdxExpression.Tokenizer

  property "generated valid expressions canonicalize exactly and idempotently" do
    check all(
            {input, expected} <- ExpressionGenerator.expression(),
            max_runs: 250,
            initial_seed: 20_260_812
          ) do
      assert SpdxExpression.canonicalize(input) == {:ok, expected}
      assert SpdxExpression.canonicalize(expected) == {:ok, expected}
    end
  end

  property "generated AST semantics survive serialization and reparsing" do
    check all(
            {input, _expected} <- ExpressionGenerator.expression(),
            max_runs: 250,
            initial_seed: 20_260_813
          ) do
      assert {:ok, tokens} = Tokenizer.tokenize(input)
      assert {:ok, ast} = Parser.parse(tokens, byte_size(input))

      rendered = Canonicalizer.render(ast)

      assert {:ok, rendered_tokens} = Tokenizer.tokenize(rendered)
      assert {:ok, reparsed_ast} = Parser.parse(rendered_tokens, byte_size(rendered))
      assert Canonicalizer.render(reparsed_ast) == rendered
    end
  end
end
