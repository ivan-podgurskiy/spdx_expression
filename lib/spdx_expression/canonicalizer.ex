defmodule SpdxExpression.Canonicalizer do
  @moduledoc false

  alias SpdxExpression.Parser

  @spec render(Parser.ast()) :: String.t()
  def render({:license, identifier}), do: identifier
  def render({:group, expression}), do: "(" <> render(expression) <> ")"

  def render({:with, license, exception}),
    do: render(license) <> " WITH " <> exception

  def render({:and, left, right}), do: render(left) <> " AND " <> render(right)
  def render({:or, left, right}), do: render(left) <> " OR " <> render(right)
end
