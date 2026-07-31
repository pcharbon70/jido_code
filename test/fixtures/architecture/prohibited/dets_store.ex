defmodule ArchitectureFixture.DetsStore do
  def open, do: :dets.open_file(:product_state, [])
end
