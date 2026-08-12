defmodule SpdxExpression.Parser do
  @moduledoc false

  alias SpdxExpression.Error
  alias SpdxExpression.Registry
  alias SpdxExpression.Token

  @max_depth 128

  @type ast ::
          {:license, String.t()}
          | {:group, ast()}
          | {:with, ast(), String.t()}
          | {:and, ast(), ast()}
          | {:or, ast(), ast()}

  @typep parse_result :: {:ok, ast(), [Token.t()]} | {:error, Error.t()}

  @spec parse([Token.t()], non_neg_integer()) :: {:ok, ast()} | {:error, Error.t()}
  def parse(tokens, input_size) do
    case parse_or(tokens, input_size, 0) do
      {:ok, ast, []} -> {:ok, ast}
      {:ok, _ast, [token | _rest]} -> {:error, trailing_error(token)}
      {:error, error} -> {:error, error}
    end
  end

  @spec parse_or([Token.t()], non_neg_integer(), non_neg_integer()) :: parse_result()
  defp parse_or(tokens, input_size, depth) do
    case parse_and(tokens, input_size, depth) do
      {:ok, left, rest} -> parse_or_rest(left, rest, input_size, depth)
      {:error, error} -> {:error, error}
    end
  end

  defp parse_or_rest(left, [%Token{kind: :or} | rest], input_size, depth) do
    case parse_and(rest, input_size, depth) do
      {:ok, right, remaining} ->
        parse_or_rest({:or, left, right}, remaining, input_size, depth)

      {:error, error} ->
        {:error, error}
    end
  end

  defp parse_or_rest(left, rest, _input_size, _depth), do: {:ok, left, rest}

  @spec parse_and([Token.t()], non_neg_integer(), non_neg_integer()) :: parse_result()
  defp parse_and(tokens, input_size, depth) do
    case parse_with(tokens, input_size, depth) do
      {:ok, left, rest} -> parse_and_rest(left, rest, input_size, depth)
      {:error, error} -> {:error, error}
    end
  end

  defp parse_and_rest(left, [%Token{kind: :and} | rest], input_size, depth) do
    case parse_with(rest, input_size, depth) do
      {:ok, right, remaining} ->
        parse_and_rest({:and, left, right}, remaining, input_size, depth)

      {:error, error} ->
        {:error, error}
    end
  end

  defp parse_and_rest(left, rest, _input_size, _depth), do: {:ok, left, rest}

  @spec parse_with([Token.t()], non_neg_integer(), non_neg_integer()) :: parse_result()
  defp parse_with(tokens, input_size, depth) do
    case parse_primary(tokens, input_size, depth) do
      {:ok, left, [%Token{kind: :with} = with_token | rest]} ->
        attach_exception(left, with_token, rest, input_size)

      result ->
        result
    end
  end

  defp attach_exception({:license, _identifier} = license, _with_token, tokens, input_size) do
    case parse_exception(tokens, input_size) do
      {:ok, exception, rest} -> {:ok, {:with, license, exception}, rest}
      {:error, error} -> {:error, error}
    end
  end

  defp attach_exception(_left, with_token, _tokens, _input_size),
    do: {:error, error(:invalid_with_operand, with_token)}

  defp parse_exception([], input_size),
    do: {:error, Error.new(:unexpected_end, offset: input_size)}

  defp parse_exception([%Token{kind: :identifier} = token | rest], _input_size) do
    case Registry.resolve_exception(token.text, token.offset) do
      {:ok, canonical} -> finish_exception(canonical, rest)
      {:error, error} -> {:error, error}
    end
  end

  defp parse_exception([token | _rest], _input_size),
    do: {:error, error(:invalid_with_operand, token)}

  defp finish_exception(_canonical, [%Token{kind: :plus} = token | _rest]),
    do: {:error, error(:invalid_plus_suffix, token)}

  defp finish_exception(_canonical, [%Token{kind: :with} = token | _rest]),
    do: {:error, error(:invalid_with_operand, token)}

  defp finish_exception(canonical, rest), do: {:ok, canonical, rest}

  @spec parse_primary([Token.t()], non_neg_integer(), non_neg_integer()) :: parse_result()
  defp parse_primary([], input_size, _depth),
    do: {:error, Error.new(:unexpected_end, offset: input_size)}

  defp parse_primary([%Token{kind: :identifier} = token | rest], _input_size, _depth) do
    case Registry.resolve_license(token.text, token.offset) do
      {:ok, canonical} -> apply_plus(canonical, rest)
      {:error, error} -> {:error, error}
    end
  end

  defp parse_primary([%Token{kind: :lparen} = token | _rest], _input_size, depth)
       when depth >= @max_depth,
       do: {:error, error(:expression_too_deep, token)}

  defp parse_primary([%Token{kind: :lparen} = open | rest], input_size, depth) do
    case parse_or(rest, input_size, depth + 1) do
      {:ok, ast, [%Token{kind: :rparen} | remaining]} ->
        {:ok, {:group, ast}, remaining}

      {:ok, _ast, []} ->
        {:error, error(:unbalanced_parenthesis, open)}

      {:ok, _ast, [token | _remaining]} ->
        {:error, group_closing_error(token)}

      {:error, error} ->
        {:error, error}
    end
  end

  defp parse_primary([%Token{kind: :plus} = token | _rest], _input_size, _depth),
    do: {:error, error(:invalid_plus_suffix, token)}

  defp parse_primary([%Token{kind: :rparen} = token | _rest], _input_size, 0),
    do: {:error, error(:unbalanced_parenthesis, token)}

  defp parse_primary([token | _rest], _input_size, _depth),
    do: {:error, error(:unexpected_token, token)}

  defp apply_plus(canonical, [%Token{kind: :plus} = token | rest]) do
    if String.starts_with?(canonical, "LicenseRef-") do
      {:error, error(:invalid_plus_suffix, token)}
    else
      {:ok, {:license, canonical <> "+"}, rest}
    end
  end

  defp apply_plus(canonical, rest), do: {:ok, {:license, canonical}, rest}

  defp trailing_error(%Token{kind: :rparen} = token),
    do: error(:unbalanced_parenthesis, token)

  defp trailing_error(%Token{kind: :plus} = token),
    do: error(:invalid_plus_suffix, token)

  defp trailing_error(%Token{kind: :with} = token),
    do: error(:invalid_with_operand, token)

  defp trailing_error(token), do: error(:unexpected_token, token)

  defp group_closing_error(%Token{kind: :plus} = token),
    do: error(:invalid_plus_suffix, token)

  defp group_closing_error(%Token{kind: :with} = token),
    do: error(:invalid_with_operand, token)

  defp group_closing_error(token), do: error(:unexpected_token, token)

  defp error(kind, token), do: Error.new(kind, token: token.text, offset: token.offset)
end
