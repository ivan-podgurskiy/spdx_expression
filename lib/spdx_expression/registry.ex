defmodule SpdxExpression.Registry do
  @moduledoc false

  alias SpdxExpression.Data
  alias SpdxExpression.Error

  @license_ref_prefix "licenseref-"
  @license_ref_prefix_size byte_size(@license_ref_prefix)
  @license_ref_suffix ~r/\A[A-Za-z0-9.-]+\z/

  @spec resolve_license(String.t(), non_neg_integer()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def resolve_license(identifier, offset) do
    lowercase_identifier = String.downcase(identifier)

    if String.starts_with?(lowercase_identifier, @license_ref_prefix) do
      resolve_license_ref(identifier, offset)
    else
      resolve_spdx_license(identifier, lowercase_identifier, offset)
    end
  end

  @spec resolve_exception(String.t(), non_neg_integer()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def resolve_exception(identifier, offset) do
    case Data.lookup_exception(String.downcase(identifier)) do
      {canonical, false} ->
        {:ok, canonical}

      {_canonical, true} ->
        {:error, Error.new(:deprecated_exception, token: identifier, offset: offset)}

      nil ->
        {:error, Error.new(:unknown_exception, token: identifier, offset: offset)}
    end
  end

  defp resolve_license_ref(identifier, offset) do
    suffix_size = byte_size(identifier) - @license_ref_prefix_size
    suffix = binary_part(identifier, @license_ref_prefix_size, suffix_size)

    if Regex.match?(@license_ref_suffix, suffix) do
      {:ok, "LicenseRef-" <> suffix}
    else
      {:error, Error.new(:invalid_license_ref, token: identifier, offset: offset)}
    end
  end

  defp resolve_spdx_license(identifier, lowercase_identifier, offset) do
    case Data.lookup_license(lowercase_identifier) do
      {canonical, false} ->
        {:ok, canonical}

      {_canonical, true} ->
        {:error, Error.new(:deprecated_license, token: identifier, offset: offset)}

      nil ->
        {:error, Error.new(:unknown_license, token: identifier, offset: offset)}
    end
  end
end
