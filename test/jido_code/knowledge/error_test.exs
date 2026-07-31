defmodule JidoCode.Knowledge.ErrorTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error

  test "defines every public failure with fixed redacted fields" do
    assert Error.kinds() == [
             :unavailable,
             :incompatible,
             :locked,
             :corrupt,
             :invalid_input,
             :unauthorized,
             :conflict,
             :stale_precondition,
             :timeout,
             :persistence_failure
           ]

    for kind <- Error.kinds() do
      error = Error.new(kind, :execute_command)

      assert error.kind == kind
      assert error.operation == :execute_command
      assert error.retry in [:retry, :verify_receipt, :refresh, :never]
      refute error.message =~ "/"
      refute Map.has_key?(Map.from_struct(error), :details)
    end
  end

  test "requires bounded kinds and source-defined operation atoms" do
    assert_raise ArgumentError, fn -> Error.new(:unknown, :query) end
    assert_raise ArgumentError, fn -> Error.new(:unavailable, "dynamic-query") end
  end
end
