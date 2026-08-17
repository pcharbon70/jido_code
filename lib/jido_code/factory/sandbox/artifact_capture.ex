defmodule JidoCode.Factory.Sandbox.ArtifactCapture do
  @moduledoc "Bounded artifact promotion without a product-owned blob store."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @max_retention_seconds 2_592_000

  @spec capture(map(), map(), keyword()) :: {:ok, struct()} | {:error, AdapterError.t()}
  def capture(candidate, context, options \\ [])

  def capture(candidate, context, options)
      when is_map(candidate) and is_map(context) and is_list(options) do
    with content when is_binary(content) <- candidate[:content],
         %DateTime{} = now <- Keyword.get(options, :now, DateTime.utc_now()),
         retention when is_integer(retention) and retention in 1..@max_retention_seconds <-
           Keyword.get(options, :retention_seconds, 86_400),
         attributes <- artifact_attributes(candidate, context),
         result <- embedded_or_external(attributes, content, now, retention, options) do
      normalize(result)
    else
      _invalid -> invalid(:sandbox_artifact_capture)
    end
  rescue
    _error -> invalid(:sandbox_artifact_capture)
  end

  def capture(_candidate, _context, _options), do: invalid(:sandbox_artifact_capture)

  defp embedded_or_external(attributes, content, now, retention, options) do
    embedded =
      attributes
      |> Map.merge(%{
        content: content,
        content_digest: nil,
        byte_count: nil,
        external_uri: nil
      })
      |> Knowledge.execution_artifact()

    case embedded do
      {:ok, artifact} ->
        {:ok, artifact}

      {:error, _error} ->
        external(attributes, content, now, retention, options)
    end
  end

  defp external(attributes, content, now, retention, options) do
    digest = "sha256:" <> Base.encode16(:crypto.hash(:sha256, content), case: :lower)

    with {module, store} when is_atom(module) <- Keyword.get(options, :artifact_store),
         true <- artifact_store?(module),
         {:ok, uri} <-
           module.put(store, %{
             content: content,
             content_digest: digest,
             byte_count: byte_size(content),
             media_type: attributes.media_type,
             retain_until: DateTime.add(now, retention, :second)
           }),
         {:ok, artifact} <-
           attributes
           |> Map.merge(%{
             content: nil,
             content_digest: digest,
             byte_count: byte_size(content),
             external_uri: uri
           })
           |> Knowledge.execution_artifact() do
      {:ok, artifact}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:sandbox_artifact_store)
    end
  end

  defp artifact_attributes(candidate, context) do
    %{
      kind: Map.get(candidate, :kind, :generated),
      base_snapshot_iri: context[:base_snapshot_iri],
      generator_iri: context[:generator_iri],
      media_type: candidate[:media_type],
      sensitivity: candidate[:sensitivity],
      affected_paths: Map.get(candidate, :affected_paths, []),
      affected_symbols: Map.get(candidate, :affected_symbols, []),
      proposed_commit_iri: candidate[:proposed_commit_iri],
      proposed_tree_iri: candidate[:proposed_tree_iri],
      findings: Map.get(candidate, :findings, [])
    }
  end

  defp normalize({:ok, artifact}), do: {:ok, artifact}
  defp normalize(_invalid), do: invalid(:sandbox_artifact_capture)

  defp artifact_store?(module),
    do: Code.ensure_loaded?(module) and function_exported?(module, :put, 2)

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
