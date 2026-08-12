defmodule SpdxExpression.Error do
  @moduledoc """
  Structured validation error returned by `SpdxExpression`.

  Offsets are zero-based byte offsets into the original input.
  """

  @type kind ::
          :invalid_type
          | :empty_expression
          | :invalid_character
          | :unexpected_token
          | :unexpected_end
          | :unbalanced_parenthesis
          | :unknown_license
          | :unknown_exception
          | :deprecated_license
          | :deprecated_exception
          | :invalid_license_ref
          | :invalid_plus_suffix
          | :invalid_with_operand
          | :expression_too_long
          | :expression_too_deep

  @type t :: %__MODULE__{
          kind: kind(),
          message: String.t(),
          token: String.t() | nil,
          offset: non_neg_integer() | nil,
          suggestion: String.t() | nil
        }

  defexception [:kind, :message, :token, :offset, :suggestion]

  @doc false
  @spec new(kind(), keyword()) :: t()
  def new(kind, options \\ []) do
    token = Keyword.get(options, :token)
    offset = Keyword.get(options, :offset)

    %__MODULE__{
      kind: kind,
      message: message(kind, token, offset),
      token: token,
      offset: offset,
      suggestion: nil
    }
  end

  @impl Exception
  def exception(options) do
    {kind, fields} = Keyword.pop!(options, :kind)
    new(kind, fields)
  end

  defp message(:invalid_type, _token, _offset),
    do: "expected a binary SPDX license expression"

  defp message(:empty_expression, _token, offset),
    do: "SPDX license expression is empty#{at(offset)}"

  defp message(:invalid_character, token, offset),
    do: "invalid character #{quoted(token)}#{at(offset)}"

  defp message(:unexpected_token, token, offset),
    do: "unexpected token #{quoted(token)}#{at(offset)}"

  defp message(:unexpected_end, _token, offset),
    do: "unexpected end of SPDX license expression#{at(offset)}"

  defp message(:unbalanced_parenthesis, token, offset),
    do: "unbalanced parenthesis #{quoted(token)}#{at(offset)}"

  defp message(:unknown_license, token, offset),
    do: "unknown SPDX license identifier #{quoted(token)}#{at(offset)}"

  defp message(:unknown_exception, token, offset),
    do: "unknown SPDX license exception #{quoted(token)}#{at(offset)}"

  defp message(:deprecated_license, token, offset),
    do: "deprecated SPDX license identifier #{quoted(token)}#{at(offset)}"

  defp message(:deprecated_exception, token, offset),
    do: "deprecated SPDX license exception #{quoted(token)}#{at(offset)}"

  defp message(:invalid_license_ref, token, offset),
    do: "invalid LicenseRef identifier #{quoted(token)}#{at(offset)}"

  defp message(:invalid_plus_suffix, token, offset),
    do: "invalid SPDX plus suffix #{quoted(token)}#{at(offset)}"

  defp message(:invalid_with_operand, token, offset),
    do: "WITH requires a simple license and an SPDX exception#{token_suffix(token)}#{at(offset)}"

  defp message(:expression_too_long, _token, offset),
    do: "SPDX license expression exceeds 65536 bytes#{at(offset)}"

  defp message(:expression_too_deep, _token, offset),
    do: "SPDX license expression exceeds 128 parenthesis levels#{at(offset)}"

  defp at(nil), do: ""
  defp at(offset), do: " at byte #{offset}"

  defp quoted(token) when is_binary(token), do: inspect(token)
  defp quoted(_token), do: "<token>"

  defp token_suffix(token) when is_binary(token), do: " near #{inspect(token)}"
  defp token_suffix(_token), do: ""
end
