defmodule JidoCode.Factory.ManagedCoding.ContextDirectiveExecutor do
  @moduledoc "Compiles and commits exact context while returning only bounded references."

  @behaviour JidoCode.Factory.Ports.ManagedCodingDirective

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Context
  alias JidoCode.Factory.ManagedCoding.Identity

  @impl true
  def execute(state, %{kind: :context} = envelope, _options) when is_map(state) do
    with attributes when is_map(attributes) <- envelope.payload[:context],
         {:ok, context} <- Context.compile(attributes, Map.get(state, :compiler_options, [])),
         :ok <- persist(state, context),
         {:ok, model_invocation_iri} <-
           Identity.deterministic(
             :model_invocation,
             Enum.join(
               [envelope.attempt_iri, envelope.fencing_token, envelope.sequence, context.digest],
               "|"
             )
           ) do
      {:ok,
       %{
         outcome: :completed,
         context_digest: context.digest,
         context_manifest_iri: context.compiled.manifest.iri,
         model_invocation_iri: model_invocation_iri,
         revision_fingerprint: context.fingerprint,
         omission_count: length(context.compiled.omissions)
       }}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :managed_coding_context_directive)}
  end

  def execute(_state, _envelope, _options), do: invalid()

  defp persist(%{context_sink: {module, sink}}, context) when is_atom(module) do
    case module.put(sink, context) do
      :ok -> :ok
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:corrupt, :managed_coding_context_sink)}
    end
  end

  defp persist(_state, _context), do: :ok
  defp invalid, do: {:error, AdapterError.new(:invalid_input, :managed_coding_context_directive)}
end
