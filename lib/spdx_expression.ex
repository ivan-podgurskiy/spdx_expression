defmodule SpdxExpression do
  @moduledoc """
  Validates and canonicalizes PEP 639-compatible SPDX license expressions.

  This module validates syntax and identifiers. It does not determine legal
  compatibility or organizational license policy.
  """

  alias SpdxExpression.Canonicalizer
  alias SpdxExpression.Data
  alias SpdxExpression.Error
  alias SpdxExpression.Parser
  alias SpdxExpression.Tokenizer

  @maximum_input_size 65_536

  @doc """
  Validates and canonicalizes an SPDX license expression.

  ## Examples

      iex> SpdxExpression.canonicalize("mit and (apache-2.0 or bsd-2-clause)")
      {:ok, "MIT AND (Apache-2.0 OR BSD-2-Clause)"}

      iex> {:error, error} = SpdxExpression.canonicalize("Unknown-License")
      iex> error.kind
      :unknown_license

  """
  @spec canonicalize(term()) :: {:ok, String.t()} | {:error, Error.t()}
  def canonicalize(input) when not is_binary(input),
    do: {:error, Error.new(:invalid_type)}

  def canonicalize(input) when byte_size(input) > @maximum_input_size,
    do: {:error, Error.new(:expression_too_long, offset: @maximum_input_size)}

  def canonicalize(input) do
    with {:ok, tokens} <- Tokenizer.tokenize(input),
         :ok <- require_tokens(tokens),
         {:ok, ast} <- Parser.parse(tokens, byte_size(input)) do
      {:ok, Canonicalizer.render(ast)}
    end
  end

  @doc """
  Validates and canonicalizes an expression, raising on invalid input.

  ## Examples

      iex> SpdxExpression.canonicalize!("mit")
      "MIT"

  """
  @spec canonicalize!(term()) :: String.t()
  def canonicalize!(input) do
    case canonicalize(input) do
      {:ok, canonical} -> canonical
      {:error, error} -> raise error
    end
  end

  @doc """
  Returns whether a term is a supported, non-deprecated SPDX expression.

  ## Examples

      iex> SpdxExpression.valid?("MIT OR Apache-2.0")
      true

      iex> SpdxExpression.valid?("Unknown-License")
      false

  """
  @spec valid?(term()) :: boolean()
  def valid?(input) do
    case canonicalize(input) do
      {:ok, _canonical} -> true
      {:error, _error} -> false
    end
  end

  @doc """
  Returns the embedded SPDX License List version.

  ## Examples

      iex> SpdxExpression.license_list_version()
      "3.28.0"

  """
  @spec license_list_version() :: String.t()
  def license_list_version, do: Data.license_list_version()

  defp require_tokens([]), do: {:error, Error.new(:empty_expression, offset: 0)}
  defp require_tokens(_tokens), do: :ok
end
