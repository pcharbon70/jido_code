defmodule JidoCode.Knowledge.RepositoryWiki.SynthesisRequest do
  @moduledoc "Closed controller-owned future synthesis request and invocation intent."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.Command
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.ResourceIdentity

  @keys ~w[
    repository_iri tenant_iri actor_iri session_iri attempt_iri edition_iri reservation_iri
    invocation_iri profile_iri price_iri provider model source_fence source_facts
    retrieval_context prompt_digest output_schema token_limits redaction_policy recorded_at
  ]a
  @token_dimensions [:input, :output, :cached, :reasoning]

  @spec new(map(), map()) :: {:ok, map()} | {:error, Error.t()}
  def new(attributes, context) when is_map(attributes) and is_map(context) do
    with true <- Enum.sort(Map.keys(attributes)) == Enum.sort(@keys),
         true <- context[:controller_authenticated?] == true,
         :ok <- resources(attributes),
         true <- attributes.repository_iri == context[:repository_iri],
         true <- attributes.tenant_iri == context[:tenant_iri],
         true <- attributes.profile_iri == context[:profile_iri],
         true <- attributes.price_iri == context[:price_iri],
         true <- attributes.provider == context[:provider],
         true <- attributes.model == context[:model],
         true <- bounded?(attributes.provider, 128),
         true <- bounded?(attributes.model, 128),
         true <- bounded?(attributes.source_fence, 512),
         true <- Contract.digest?(attributes.prompt_digest),
         true <- attributes.output_schema == :wiki_synthesis_fragment_v1,
         true <- attributes.redaction_policy == :secrets_and_private_content,
         :ok <- token_limits(attributes.token_limits),
         :ok <- source_facts(attributes.source_facts),
         :ok <- retrieval_context(attributes.retrieval_context),
         %DateTime{} = recorded_at <- attributes.recorded_at,
         true <- recorded_at == DateTime.truncate(recorded_at, :microsecond),
         material <- Map.take(attributes, @keys),
         digest <- Contract.digest(material),
         {:ok, iri} <-
           ResourceIdentity.deterministic(:wiki_compilation_attempt, "synthesis\n" <> digest) do
      {:ok, material |> Map.put(:iri, iri) |> Map.put(:digest, digest)}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:wiki_synthesis_request)
    end
  rescue
    _error -> invalid(:wiki_synthesis_request)
  end

  def new(_attributes, _context), do: invalid(:wiki_synthesis_request)

  @spec invocation_command(map(), map(), keyword()) ::
          {:ok, JidoCode.Knowledge.CommandEnvelope.t()} | {:error, Error.t()}
  def invocation_command(request, attributes, options \\ [])

  def invocation_command(request, attributes, options)
      when is_map(request) and is_map(attributes) and is_list(options) do
    run_graph = attributes[:run_graph_iri]
    control_graph = attributes[:control_graph_iri]
    run_revision = attributes[:expected_run_revision]
    control_revision = attributes[:expected_control_revision]
    jf = "https://jido.run/ontology/factory#"

    with {:ok, :run_attempt} <- GraphRegistry.identify(run_graph),
         {:ok, :repository_control} <- GraphRegistry.identify(control_graph),
         true <- is_integer(run_revision) and run_revision > 0,
         true <- is_integer(control_revision) and control_revision > 0,
         additions = [
           {request.invocation_iri, RDF.type(), RDF.iri(jf <> "ModelInvocation")},
           {request.invocation_iri, jf <> "repositoryScope", RDF.iri(request.repository_iri)},
           {request.invocation_iri, jf <> "wikiCompilationAttempt", RDF.iri(request.attempt_iri)},
           {request.invocation_iri, jf <> "wikiReservation", RDF.iri(request.reservation_iri)},
           {request.invocation_iri, jf <> "sourceFence",
            RDF.XSD.String.new(request.source_fence)},
           {request.invocation_iri, jf <> "profileDigest", RDF.XSD.String.new(request.digest)},
           {request.invocation_iri, jf <> "generatedAtTime",
            RDF.XSD.DateTime.new(request.recorded_at)}
         ],
         target = %{
           family: :run_attempt,
           graph_iri: run_graph,
           operation: :append,
           metadata: %{lifecycle_state: :open},
           additions: additions,
           supersessions: [],
           invalidations: [],
           removals: []
         },
         guards = [
           {:subject_present, control_graph, request.reservation_iri},
           {:subject_absent, run_graph, request.invocation_iri}
         ],
         command_attributes <-
           attributes
           |> Map.put(:command_version, Protocol.runtime_semantic_version())
           |> Map.put(:repository_iri, request.repository_iri)
           |> Map.put(:source_fence, request.source_fence)
           |> Map.put(:expected_graph_revisions, %{
             run_graph => run_revision,
             control_graph => control_revision
           }),
         {:ok, command} <-
           Command.build(
             "InvokeWikiSynthesis",
             request.digest,
             [target],
             guards,
             command_attributes,
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:invoke_wiki_synthesis)
    end
  end

  def invocation_command(_request, _attributes, _options), do: invalid(:invoke_wiki_synthesis)

  defp resources(attributes) do
    Enum.reduce_while(
      ~w[
        repository_iri tenant_iri actor_iri session_iri attempt_iri edition_iri reservation_iri
        invocation_iri profile_iri price_iri
      ]a,
      :ok,
      fn key, :ok ->
        case Contract.resource(attributes[key]) do
          :ok -> {:cont, :ok}
          {:error, %Error{} = error} -> {:halt, {:error, error}}
        end
      end
    )
  end

  defp token_limits(value) when is_map(value) do
    if Enum.sort(Map.keys(value)) == Enum.sort(@token_dimensions) and
         Enum.all?(@token_dimensions, &(is_integer(value[&1]) and value[&1] >= 0)) and
         value.input > 0 and value.output > 0 do
      :ok
    else
      invalid(:wiki_synthesis_token_limits)
    end
  end

  defp token_limits(_value), do: invalid(:wiki_synthesis_token_limits)

  defp source_facts(values) when is_list(values) and length(values) in 1..128 do
    if Enum.all?(values, fn value ->
         is_map(value) and Enum.sort(Map.keys(value)) == [:digest, :kind, :resource_iri] and
           Contract.resource(value.resource_iri) == :ok and Contract.digest?(value.digest) and
           value.kind in [:source, :dependency, :guide, :accepted_document]
       end) do
      :ok
    else
      invalid(:wiki_synthesis_source_facts)
    end
  end

  defp source_facts(_values), do: invalid(:wiki_synthesis_source_facts)

  defp retrieval_context(values) when is_list(values) and length(values) <= 64 do
    if Enum.all?(values, &(Contract.resource(&1) == :ok)),
      do: :ok,
      else: invalid(:wiki_synthesis_retrieval_context)
  end

  defp retrieval_context(_values), do: invalid(:wiki_synthesis_retrieval_context)
  defp bounded?(value, maximum), do: is_binary(value) and byte_size(value) in 1..maximum
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
