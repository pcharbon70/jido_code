defmodule JidoCode.Knowledge.ChangeFeed do
  @moduledoc """
  Disposable post-commit notification boundary.

  Topics have fixed length and are derived only from validated semantic scope.
  Subscribers use events as wake-up hints and re-query authoritative graph
  projections from their last evaluated dataset revision.
  """

  alias JidoCode.Knowledge.ChangeEvent
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.CommandReceipt
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @topic_prefix "jido-code:changes:v1:"
  @message_tag :jido_code_change

  @spec subscribe(String.t(), atom()) :: :ok | {:error, Error.t()}
  def subscribe(scope_iri, pubsub \\ JidoCode.PubSub) when is_atom(pubsub) do
    with {:ok, topic} <- topic(scope_iri) do
      Phoenix.PubSub.subscribe(pubsub, topic)
    end
  catch
    :exit, _reason -> {:error, Error.new(:unavailable, :change_subscription)}
  end

  @spec publish(CommandEnvelope.t(), CommandReceipt.t(), atom()) :: :ok | :dropped
  def publish(envelope, receipt, pubsub \\ JidoCode.PubSub)

  def publish(%CommandEnvelope{} = envelope, %CommandReceipt{} = receipt, pubsub)
      when is_atom(pubsub) do
    with {:ok, event} <- ChangeEvent.new(envelope, receipt),
         {:ok, topic} <- topic(envelope.scope_iri),
         :ok <- Phoenix.PubSub.broadcast(pubsub, topic, {@message_tag, event}) do
      :ok
    else
      _unavailable -> :dropped
    end
  rescue
    _error -> :dropped
  catch
    :exit, _reason -> :dropped
  end

  def publish(_envelope, _receipt, _pubsub), do: :dropped

  @spec topic(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def topic(scope_iri) when is_binary(scope_iri) do
    with :ok <- ResourceIdentity.validate(scope_iri) do
      digest = :crypto.hash(:sha256, scope_iri) |> Base.encode16(case: :lower)
      {:ok, @topic_prefix <> digest}
    else
      _invalid -> {:error, Error.new(:invalid_input, :change_scope)}
    end
  end

  def topic(_scope_iri), do: {:error, Error.new(:invalid_input, :change_scope)}

  @spec requery(ChangeEvent.t(), non_neg_integer()) :: :ignore | {:refresh, map()}
  def requery(%ChangeEvent{} = event, known_dataset_revision)
      when is_integer(known_dataset_revision) and known_dataset_revision >= 0 do
    if event.dataset_revision > known_dataset_revision do
      {:refresh,
       %{
         after_dataset_revision: known_dataset_revision,
         hinted_dataset_revision: event.dataset_revision
       }}
    else
      :ignore
    end
  end

  def requery(_event, _known_dataset_revision), do: :ignore
end
