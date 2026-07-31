defmodule ArchitectureFixture.MnesiaStore do
  def create, do: :mnesia.create_table(:product_state)
end
