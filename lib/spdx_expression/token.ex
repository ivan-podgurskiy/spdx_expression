defmodule SpdxExpression.Token do
  @moduledoc false

  @type kind :: :identifier | :and | :or | :with | :lparen | :rparen | :plus

  @type t :: %__MODULE__{
          kind: kind(),
          text: binary(),
          offset: non_neg_integer()
        }

  @enforce_keys [:kind, :text, :offset]
  defstruct [:kind, :text, :offset]
end
