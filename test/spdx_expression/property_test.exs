defmodule SpdxExpression.PropertyTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias SpdxExpression.Test.ExpressionGenerator

  alias SpdxExpression.Canonicalizer
  alias SpdxExpression.Error
  alias SpdxExpression.Parser
  alias SpdxExpression.Registry
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

  property "registry returns exact embedded license spelling and deprecation status" do
    check all(
            %{"licenseId" => id, "isDeprecatedLicenseId" => deprecated?} <-
              ExpressionGenerator.license_entry(),
            max_runs: 500,
            initial_seed: 20_260_814
          ) do
      if deprecated? do
        assert {:error, %Error{kind: :deprecated_license, token: ^id, offset: 17}} =
                 Registry.resolve_license(id, 17)
      else
        assert Registry.resolve_license(String.downcase(id), 17) == {:ok, id}
      end
    end
  end

  property "registry returns exact embedded exception spelling and deprecation status" do
    check all(
            %{"licenseExceptionId" => id, "isDeprecatedLicenseId" => deprecated?} <-
              ExpressionGenerator.exception_entry(),
            max_runs: 250,
            initial_seed: 20_260_815
          ) do
      if deprecated? do
        assert {:error, %Error{kind: :deprecated_exception, token: ^id, offset: 23}} =
                 Registry.resolve_exception(id, 23)
      else
        assert Registry.resolve_exception(String.downcase(id), 23) == {:ok, id}
      end
    end
  end

  property "arbitrary binaries cannot crash non-bang APIs or create atoms" do
    SpdxExpression.canonicalize("MIT")
    SpdxExpression.canonicalize(<<0xFF>>)
    SpdxExpression.valid?("MIT")

    check all(
            _warmup <- StreamData.binary(max_length: 1),
            max_runs: 1,
            initial_seed: 20_260_816
          ) do
      :ok
    end

    :erlang.garbage_collect()
    atom_count_before = :erlang.system_info(:atom_count)

    check all(
            input <- StreamData.binary(max_length: 512),
            max_runs: 1_000,
            initial_seed: 20_260_816
          ) do
      case SpdxExpression.canonicalize(input) do
        {:ok, canonical} when is_binary(canonical) ->
          assert SpdxExpression.valid?(input)

        {:error, %Error{}} ->
          refute SpdxExpression.valid?(input)

        other ->
          flunk("unexpected canonicalize/1 result: #{inspect(other)}")
      end
    end

    :erlang.garbage_collect()
    assert :erlang.system_info(:atom_count) == atom_count_before
  end
end
