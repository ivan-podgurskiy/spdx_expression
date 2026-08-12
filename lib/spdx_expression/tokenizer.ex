defmodule SpdxExpression.Tokenizer do
  @moduledoc false

  alias SpdxExpression.Error
  alias SpdxExpression.Token

  defguardp is_ascii_whitespace(byte)
            when byte == 0x09 or byte == 0x0A or byte == 0x0B or byte == 0x0C or
                   byte == 0x0D or byte == 0x20

  defguardp is_identifier_byte(byte)
            when byte in ?A..?Z or byte in ?a..?z or byte in ?0..?9 or byte == ?. or
                   byte == ?- or byte == ?_

  @spec tokenize(binary()) :: {:ok, [Token.t()]} | {:error, Error.t()}
  def tokenize(input) when is_binary(input), do: scan(input, 0, [])

  defp scan(<<>>, _offset, tokens), do: {:ok, Enum.reverse(tokens)}

  defp scan(<<byte, rest::binary>>, offset, tokens) when is_ascii_whitespace(byte),
    do: scan(rest, offset + 1, tokens)

  defp scan(<<?(, rest::binary>>, offset, tokens),
    do: scan(rest, offset + 1, [token(:lparen, "(", offset) | tokens])

  defp scan(<<?), rest::binary>>, offset, tokens),
    do: scan(rest, offset + 1, [token(:rparen, ")", offset) | tokens])

  defp scan(<<?+, rest::binary>>, offset, tokens),
    do: scan(rest, offset + 1, [token(:plus, "+", offset) | tokens])

  defp scan(<<byte, _rest::binary>> = input, offset, tokens) when is_identifier_byte(byte) do
    {text, rest, size} = take_identifier(input)

    case invalid_underscore_offset(text) do
      nil -> scan(rest, offset + size, [token(kind(text), text, offset) | tokens])
      relative_offset -> invalid_character("_", offset + relative_offset)
    end
  end

  defp scan(<<byte, _rest::binary>>, offset, _tokens),
    do: invalid_character(<<byte>>, offset)

  defp take_identifier(input), do: take_identifier(input, input, 0)

  defp take_identifier(original, <<byte, rest::binary>>, size) when is_identifier_byte(byte),
    do: take_identifier(original, rest, size + 1)

  defp take_identifier(original, rest, size),
    do: {binary_part(original, 0, size), rest, size}

  defp invalid_underscore_offset(text) do
    case :binary.match(text, "_") do
      :nomatch ->
        nil

      {offset, 1} ->
        if String.starts_with?(String.downcase(text), "licenseref-"), do: nil, else: offset
    end
  end

  defp kind(text) do
    case String.downcase(text) do
      "and" -> :and
      "or" -> :or
      "with" -> :with
      _identifier -> :identifier
    end
  end

  defp token(kind, text, offset), do: %Token{kind: kind, text: text, offset: offset}

  defp invalid_character(character, offset),
    do: {:error, Error.new(:invalid_character, token: character, offset: offset)}
end
