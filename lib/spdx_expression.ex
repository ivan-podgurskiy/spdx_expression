defmodule SpdxExpression do
  @moduledoc """
  Validates and canonicalizes PEP 639-compatible SPDX license expressions.

  This module validates syntax and identifiers. It does not determine legal
  compatibility or organizational license policy.
  """

  @license_list_version "3.28.0"

  @doc """
  Returns the embedded SPDX License List version.

  ## Examples

      iex> SpdxExpression.license_list_version()
      "3.28.0"

  """
  @spec license_list_version() :: String.t()
  def license_list_version, do: @license_list_version
end
