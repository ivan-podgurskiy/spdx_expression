defmodule SpdxExpression.TokenizerTest do
  use ExUnit.Case, async: true

  alias SpdxExpression.Error
  alias SpdxExpression.Tokenizer

  test "tokenizes operators, punctuation, identifiers, and original byte offsets" do
    assert {:ok, tokens} = Tokenizer.tokenize(" mit\tAND\n(Apache-2.0+) ")

    assert Enum.map(tokens, &{&1.kind, &1.text, &1.offset}) == [
             {:identifier, "mit", 1},
             {:and, "AND", 5},
             {:lparen, "(", 9},
             {:identifier, "Apache-2.0", 10},
             {:plus, "+", 20},
             {:rparen, ")", 21}
           ]
  end

  test "recognizes operators case-insensitively only as complete tokens" do
    assert {:ok, tokens} = Tokenizer.tokenize("aNd or WiTh ANDOR")

    assert Enum.map(tokens, & &1.kind) == [:and, :or, :with, :identifier]
    assert List.last(tokens).text == "ANDOR"
  end

  test "skips exactly the six ASCII whitespace bytes" do
    whitespace = <<0x20, 0x09, 0x0A, 0x0D, 0x0C, 0x0B>>

    assert {:ok, [token]} = Tokenizer.tokenize(whitespace <> "MIT" <> whitespace)
    assert {token.kind, token.text, token.offset} == {:identifier, "MIT", 6}
  end

  test "returns an empty token list for empty or whitespace-only input" do
    assert Tokenizer.tokenize("") == {:ok, []}
    assert Tokenizer.tokenize(" \t\r\n\f\v") == {:ok, []}
  end

  test "preserves underscore in LicenseRef candidates for semantic validation" do
    assert {:ok, [token]} = Tokenizer.tokenize("LicenseRef-Acme_Internal")

    assert {token.kind, token.text, token.offset} ==
             {:identifier, "LicenseRef-Acme_Internal", 0}
  end

  test "rejects underscore in other identifier candidates" do
    assert {:error, %Error{kind: :invalid_character, token: "_", offset: 3}} =
             Tokenizer.tokenize("MIT_or")
  end

  test "rejects unsupported ASCII punctuation at its byte offset" do
    assert {:error, %Error{kind: :invalid_character, token: "@", offset: 3}} =
             Tokenizer.tokenize("MIT@Apache-2.0")
  end

  test "rejects Unicode whitespace at its first byte" do
    assert {:error, %Error{kind: :invalid_character, offset: 3}} =
             Tokenizer.tokenize("MIT\u00A0OR Apache-2.0")
  end

  test "rejects malformed UTF-8 without crashing" do
    assert {:error, %Error{kind: :invalid_character, token: <<0xFF>>, offset: 3}} =
             Tokenizer.tokenize(<<"MIT", 0xFF>>)
  end
end
