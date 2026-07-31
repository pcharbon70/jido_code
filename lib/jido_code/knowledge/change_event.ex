defmodule JidoCode.Knowledge.ChangeEvent do
  @moduledoc """
  Disposable, bounded wake-up hint emitted after a semantic commit.

  Events contain revision and routing metadata only. They are never a source
  of graph state and deliberately omit command bodies and authority context.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.CommandReceipt
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry

  @derive {Inspect,
           only: [
             :dataset_revision,
             :affected_graphs,
             :scope_iri,
             :command_class,
             :receipt_iri
           ]}
  @enforce_keys [
    :dataset_revision,
    :affected_graphs,
    :scope_iri,
    :command_class,
    :receipt_iri
  ]
  defstruct @enforce_keys

  @type affected_graph :: %{family: atom(), revision: pos_integer()}
  @type t :: %__MODULE__{
          dataset_revision: pos_integer(),
          affected_graphs: [affected_graph()],
          scope_iri: String.t(),
          command_class: String.t(),
          receipt_iri: String.t()
        }

  @spec new(CommandEnvelope.t(), CommandReceipt.t()) :: {:ok, t()} | {:error, Error.t()}
  def new(
        %CommandEnvelope{} = envelope,
        %CommandReceipt{outcome: :committed, graph_revisions: revisions} = receipt
      )
      when is_map(revisions) do
    with true <- is_integer(receipt.dataset_revision) and receipt.dataset_revision > 0,
         true <- is_binary(receipt.receipt_iri),
         {:ok, affected_graphs} <- affected_graphs(revisions),
         true <- affected_graphs != [] do
      {:ok,
       %__MODULE__{
         dataset_revision: receipt.dataset_revision,
         affected_graphs: affected_graphs,
         scope_iri: envelope.scope_iri,
         command_class: envelope.command_type,
         receipt_iri: receipt.receipt_iri
       }}
    else
      _invalid -> {:error, Error.new(:invalid_input, :change_event)}
    end
  end

  def new(_envelope, _receipt), do: {:error, Error.new(:invalid_input, :change_event)}

  @spec safe_map(t()) :: map()
  def safe_map(%__MODULE__{} = event) do
    Map.from_struct(event)
  end

  defp affected_graphs(revisions) when map_size(revisions) <= 20 do
    Enum.reduce_while(revisions, {:ok, []}, fn {graph_iri, revision}, {:ok, entries} ->
      with {:ok, family} <- GraphRegistry.identify(graph_iri),
           {:ok, new_revision} <- new_revision(revision) do
        entry = %{family: family, revision: new_revision}
        {:cont, {:ok, [entry | entries]}}
      else
        _invalid -> {:halt, {:error, Error.new(:invalid_input, :change_event)}}
      end
    end)
    |> case do
      {:ok, entries} ->
        {:ok, entries |> Enum.uniq() |> Enum.sort_by(&{&1.family, &1.revision})}

      error ->
        error
    end
  end

  defp affected_graphs(_revisions), do: {:error, Error.new(:invalid_input, :change_event)}

  defp new_revision(%{new: value}) when is_integer(value) and value > 0, do: {:ok, value}
  defp new_revision(_revision), do: {:error, Error.new(:invalid_input, :change_event)}
end
