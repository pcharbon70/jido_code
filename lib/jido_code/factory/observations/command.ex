defmodule JidoCode.Factory.Observations.Command do
  @moduledoc """
  Maps normalized external observations into the reviewed observation command.

  Provider fields are mapped through a closed semantic vocabulary. Unknown
  fields remain warnings and never become caller-selected RDF predicates.
  """

  alias JidoCode.Factory.Observations.GitSnapshot
  alias JidoCode.Factory.Observations.ObservationEnvelope
  alias JidoCode.Factory.Observations.ProviderObservation
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Commands.RecordObservationBatch
  alias JidoCode.Knowledge.Error

  @jf "https://jido.run/ontology/factory#"

  @spec build(ObservationEnvelope.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def build(envelope, context, options \\ [])

  def build(%ObservationEnvelope{} = envelope, context, options)
      when is_map(context) and is_list(options) do
    with {:ok, assertions} <- assertions(envelope, context.repository_iri),
         {:ok, snapshot} <- snapshot(Map.get(context, :git_snapshot)) do
      RecordObservationBatch.build(
        %{
          repository_iri: context.repository_iri,
          repository_scope_iri: context.repository_scope_iri,
          locator_iri: envelope.locator_iri,
          enrollment: context.enrollment,
          source: envelope.source,
          delivery_identity: envelope.delivery_identity,
          retrieved_at: envelope.received_at,
          source_time: envelope.source_time,
          actor_iri: context.actor_iri,
          principal_iri: context.principal_iri,
          delegated_agent_iri: Map.get(context, :delegated_agent_iri),
          delegation_iri: Map.get(context, :delegation_iri),
          adapter_iri: context.adapter_iri,
          adapter_version: context.adapter_version,
          response_digests: Enum.map(envelope.observations, & &1.response_digest),
          request_digest: Map.get(context, :request_digest),
          coverage: envelope.completeness.covered,
          missing: envelope.completeness.missing,
          limitations: envelope.observations |> Enum.flat_map(& &1.limitations) |> Enum.uniq(),
          warnings: envelope.warnings,
          previous_batch_iri: Map.get(context, :previous_batch_iri),
          assertions: assertions ++ Map.get(context, :additional_assertions, []),
          prior_claims: Map.get(context, :prior_claims, []),
          snapshot: snapshot,
          correlation_iri: context.correlation_iri,
          causation_iri: context.causation_iri,
          expected_dataset_revision: context.expected_dataset_revision,
          reason: context.reason
        },
        options
      )
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :observation_command)}
    end
  end

  def build(_envelope, _context, _options),
    do: {:error, Error.new(:invalid_input, :observation_command)}

  defp assertions(envelope, repository_iri) do
    Enum.reduce_while(envelope.observations, {:ok, []}, fn observation, {:ok, acc} ->
      case observation_assertions(observation, envelope.locator_iri, repository_iri) do
        {:ok, values} -> {:cont, {:ok, acc ++ values}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp observation_assertions(
         %ProviderObservation{kind: :repository} = observation,
         _locator,
         repo
       ) do
    mappings = [
      {:default_branch, "defaultBranch"},
      {:visibility, "visibility"},
      {:archived, "archived"},
      {:fork, "fork"},
      {:availability, "available"}
    ]

    {:ok, mapped_assertions(repo, mappings, observation)}
  end

  defp observation_assertions(
         %ProviderObservation{kind: :capability} = observation,
         locator,
         _repo
       ) do
    with {:ok, subject} <-
           Knowledge.provider_object_identity(locator, :capability, observation.external_id) do
      permissions = Map.get(observation.data, :permissions, %{})

      assertions =
        Enum.map(permissions, fn {permission, allowed} ->
          assertion(
            subject,
            "permission",
            RDF.XSD.String.new("#{permission}:#{allowed}"),
            observation
          )
        end)

      {:ok, assertions}
    end
  end

  defp observation_assertions(%ProviderObservation{kind: kind} = observation, locator, _repo)
       when kind in [:issue, :pull_request, :branch, :ci, :webhook] do
    with {:ok, subject} <-
           Knowledge.provider_object_identity(locator, kind, observation.external_id) do
      mappings =
        case kind do
          :branch -> [{:name, "refName"}, {:commit_sha, "commitIdentity"}]
          :ci -> [{:status, "status"}, {:conclusion, "conclusion"}]
          :webhook -> [{:event, "status"}, {:after, "providerRevision"}]
          _issue_or_pr -> [{:state, "status"}]
        end

      {:ok, mapped_assertions(subject, mappings, observation)}
    end
  end

  defp mapped_assertions(subject, mappings, observation) do
    Enum.flat_map(mappings, fn {key, predicate} ->
      case fetch_data(observation.data, key) do
        :error -> []
        {:ok, value} -> [assertion(subject, predicate, rdf_value(predicate, value), observation)]
      end
    end)
  end

  defp fetch_data(data, key) do
    case Map.fetch(data, key) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(data, Atom.to_string(key))
    end
  end

  defp assertion(subject, predicate, object, observation) do
    %{
      mode: :claim,
      subject: subject,
      predicate: @jf <> predicate,
      object: object,
      epistemic_state: :observed,
      source_observed_at: observation.source_time,
      disputable?: true
    }
  end

  defp rdf_value("commitIdentity", value) when is_binary(value) do
    case Knowledge.git_object_identity(:sha1, value) do
      {:ok, iri} -> RDF.iri(iri)
      {:error, _error} -> RDF.XSD.String.new(value)
    end
  end

  defp rdf_value(_predicate, value) when is_boolean(value), do: RDF.XSD.Boolean.new(value)
  defp rdf_value(_predicate, value) when is_number(value), do: RDF.literal(value)
  defp rdf_value(_predicate, value), do: RDF.XSD.String.new(to_string(value))

  defp snapshot(nil), do: {:ok, nil}

  defp snapshot(%GitSnapshot{} = snapshot) do
    {:ok,
     snapshot
     |> Map.from_struct()
     |> Map.take([:commit_sha, :tree_sha, :parents, :ref, :object_format])}
  end

  defp snapshot(_snapshot), do: {:error, Error.new(:invalid_input, :observation_snapshot)}
end
