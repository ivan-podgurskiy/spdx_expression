defmodule SpdxExpression.Test.ExpressionGenerator do
  @moduledoc false

  import StreamData

  @licenses_path Path.expand("../../priv/spdx/3.28.0/licenses.json", __DIR__)
  @exceptions_path Path.expand("../../priv/spdx/3.28.0/exceptions.json", __DIR__)

  @license_entries @licenses_path
                   |> File.read!()
                   |> Jason.decode!()
                   |> Map.fetch!("licenses")
  @exception_entries @exceptions_path
                     |> File.read!()
                     |> Jason.decode!()
                     |> Map.fetch!("exceptions")

  @active_licenses @license_entries
                   |> Enum.reject(& &1["isDeprecatedLicenseId"])
                   |> Enum.map(&Map.fetch!(&1, "licenseId"))

  @active_exceptions @exception_entries
                     |> Enum.reject(& &1["isDeprecatedLicenseId"])
                     |> Enum.map(&Map.fetch!(&1, "licenseExceptionId"))

  @spec expression() :: StreamData.t({binary(), binary()})
  def expression do
    simple_expression()
    |> tree(fn child ->
      one_of([
        grouped(child),
        binary_expression(child, "AND"),
        binary_expression(child, "OR")
      ])
    end)
    |> resize(12)
  end

  @spec license_entry() :: StreamData.t(map())
  def license_entry, do: member_of(@license_entries)

  @spec exception_entry() :: StreamData.t(map())
  def exception_entry, do: member_of(@exception_entries)

  defp simple_expression do
    one_of([
      spdx_license(),
      license_ref(),
      plus_license(),
      with_exception()
    ])
  end

  defp spdx_license do
    bind(member_of(@active_licenses), &cased_identifier/1)
  end

  defp license_ref do
    bind(member_of(["Acme", "Acme.Internal", "Private-2", "a.b-9"]), fn suffix ->
      input = member_of(["LicenseRef-" <> suffix, "licenseref-" <> suffix])
      map(input, &{&1, "LicenseRef-" <> suffix})
    end)
  end

  defp plus_license do
    map(spdx_license(), fn {input, canonical} -> {input <> "+", canonical <> "+"} end)
  end

  defp with_exception do
    bind(one_of([spdx_license(), license_ref(), plus_license()]), fn license ->
      bind(member_of(@active_exceptions), fn exception ->
        map(
          {constant(license), cased_identifier(exception), whitespace(), operator("WITH"),
           whitespace()},
          fn {{license_input, license_canonical}, {exception_input, exception_canonical}, left_ws,
              with_input, right_ws} ->
            {
              license_input <> left_ws <> with_input <> right_ws <> exception_input,
              license_canonical <> " WITH " <> exception_canonical
            }
          end
        )
      end)
    end)
  end

  defp grouped(child) do
    map({child, whitespace(), whitespace()}, fn {{input, canonical}, left_ws, right_ws} ->
      {"(" <> left_ws <> input <> right_ws <> ")", "(" <> canonical <> ")"}
    end)
  end

  defp binary_expression(child, canonical_operator) do
    map(
      {child, child, whitespace(), operator(canonical_operator), whitespace()},
      fn {{left_input, left_canonical}, {right_input, right_canonical}, left_ws, input_operator,
          right_ws} ->
        {
          left_input <> left_ws <> input_operator <> right_ws <> right_input,
          left_canonical <> " " <> canonical_operator <> " " <> right_canonical
        }
      end
    )
  end

  defp cased_identifier(canonical) do
    canonical
    |> then(&[&1, String.downcase(&1), String.upcase(&1)])
    |> Enum.uniq()
    |> member_of()
    |> map(&{&1, canonical})
  end

  defp operator(canonical),
    do: member_of([canonical, String.downcase(canonical), alternating_case(canonical)])

  defp whitespace, do: member_of([" ", "  ", "\t", "\n", "\r\n"])

  defp alternating_case("AND"), do: "aNd"
  defp alternating_case("OR"), do: "oR"
  defp alternating_case("WITH"), do: "wItH"
end
