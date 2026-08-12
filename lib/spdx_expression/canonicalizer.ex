defmodule SpdxExpression.Canonicalizer do
  @moduledoc false

  alias SpdxExpression.Parser

  @spec render(Parser.ast()) :: String.t()
  def render(expression), do: expression |> to_iodata() |> IO.iodata_to_binary()

  defp to_iodata({:license, identifier}), do: identifier
  defp to_iodata({:group, expression}), do: ["(", to_iodata(expression), ")"]

  defp to_iodata({:with, license, exception}),
    do: [to_iodata(license), " WITH ", exception]

  defp to_iodata({:and, left, right}), do: [to_iodata(left), " AND ", to_iodata(right)]
  defp to_iodata({:or, left, right}), do: [to_iodata(left), " OR ", to_iodata(right)]
end
