defmodule JidoCode.TestSupport.FixedClock do
  @moduledoc false

  @epoch ~U[2026-01-15 12:00:00Z]

  def now(offset_seconds \\ 0) when is_integer(offset_seconds) do
    DateTime.add(@epoch, offset_seconds, :second)
  end

  def monotonic_time(offset_milliseconds \\ 0) when is_integer(offset_milliseconds) do
    System.convert_time_unit(offset_milliseconds, :millisecond, :native)
  end
end
