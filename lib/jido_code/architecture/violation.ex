defmodule JidoCode.Architecture.Violation do
  @moduledoc false

  @enforce_keys [:rule, :file, :line, :message]
  defstruct [:rule, :file, :line, :message]

  @type t :: %__MODULE__{
          rule: atom(),
          file: String.t(),
          line: pos_integer(),
          message: String.t()
        }

  def format(%__MODULE__{} = violation) do
    "#{violation.file}:#{violation.line} [#{violation.rule}] #{violation.message}"
  end
end
