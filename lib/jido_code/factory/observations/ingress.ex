defmodule JidoCode.Factory.Observations.Ingress do
  @moduledoc """
  Authenticated webhook and polling normalization boundary.

  This module performs no graph writes and owns no durable retry queue. A
  successful result is a transient observation envelope whose stable identity
  is later consumed by the semantic command boundary.
  """

  alias JidoCode.Factory.Observations.ObservationEnvelope
  alias JidoCode.Factory.Observations.ProviderObservation
  alias JidoCode.Factory.RepositoryLocator
  alias JidoCode.Knowledge.Error

  @max_body_bytes 1_000_000
  @max_delivery_age_seconds 300
  @known_events ~w[push repository issues pull_request check_run]

  @spec webhook(map()) :: {:ok, ObservationEnvelope.t()} | {:error, Error.t()}
  def webhook(attributes) when is_map(attributes) do
    body = attributes[:body]
    received_at = attributes[:received_at]
    delivered_at = attributes[:delivered_at]
    locator = attributes[:locator]
    event = attributes[:event]

    with :ok <- active_enrollment(attributes[:enrollment]),
         %RepositoryLocator{} <- locator,
         true <- valid_content_type?(attributes[:content_type]),
         true <- is_binary(body) and byte_size(body) in 1..@max_body_bytes,
         true <- valid_delivery_id?(attributes[:delivery_id]),
         true <- valid_event?(event),
         %DateTime{} <- received_at,
         %DateTime{} <- delivered_at,
         :ok <- valid_delivery_time(delivered_at, received_at),
         :ok <- verify_signature(body, attributes[:signature], attributes[:secret]),
         {:ok, payload} <- decode_body(body),
         :ok <- bound_locator(payload, locator),
         {:ok, observation} <-
           webhook_observation(event, payload, locator, received_at, digest(body)),
         delivery_identity <-
           ObservationEnvelope.delivery_identity([
             "webhook",
             locator.provider_host,
             locator.external_id,
             attributes[:delivery_id]
           ]),
         {:ok, envelope} <-
           ObservationEnvelope.new(%{
             source: :webhook,
             delivery_identity: delivery_identity,
             enrollment_iri: attributes[:enrollment].enrollment_iri,
             locator_iri: locator.iri,
             received_at: received_at,
             source_time: observation.source_time || delivered_at,
             observations: [observation],
             completeness: observation.completeness,
             warnings: observation.warnings
           }) do
      {:ok, envelope}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:webhook_ingress)
    end
  rescue
    _error -> invalid(:webhook_ingress)
  end

  def webhook(_attributes), do: invalid(:webhook_ingress)

  @spec poll(map()) :: {:ok, ObservationEnvelope.t()} | {:error, Error.t()}
  def poll(attributes) when is_map(attributes) do
    observations = attributes[:observations]
    locator = attributes[:locator]
    retrieved_at = attributes[:retrieved_at]

    with :ok <- active_enrollment(attributes[:enrollment]),
         %RepositoryLocator{} <- locator,
         true <- is_list(observations) and observations != [],
         true <- Enum.all?(observations, &match?(%ProviderObservation{}, &1)),
         %DateTime{} <- retrieved_at,
         true <- valid_delivery_id?(attributes[:poll_identity]),
         identity <-
           ObservationEnvelope.delivery_identity([
             "poll",
             locator.provider_host,
             locator.external_id,
             attributes[:poll_identity]
           ]),
         {:ok, envelope} <-
           ObservationEnvelope.new(%{
             source: :poll,
             delivery_identity: identity,
             enrollment_iri: attributes[:enrollment].enrollment_iri,
             locator_iri: locator.iri,
             received_at: retrieved_at,
             source_time: latest_source_time(observations),
             observations: observations,
             completeness: aggregate_completeness(observations),
             warnings: observations |> Enum.flat_map(& &1.warnings) |> Enum.uniq()
           }) do
      {:ok, envelope}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:poll_ingress)
    end
  rescue
    _error -> invalid(:poll_ingress)
  end

  def poll(_attributes), do: invalid(:poll_ingress)

  defp webhook_observation(event, payload, locator, retrieved_at, digest) do
    repository = Map.get(payload, "repository", %{})
    source = event_payload(event, payload)
    known? = event in @known_events

    ProviderObservation.new(%{
      kind: event_kind(event),
      external_id: event_external_id(event, source, locator),
      source_time: event_source_time(source, repository),
      retrieved_at: retrieved_at,
      etag: nil,
      source_revision: Map.get(payload, "after") || Map.get(source, "head_sha"),
      response_digest: digest,
      data: normalize_event(event, source, repository),
      completeness: %{
        status: if(known?, do: :complete, else: :partial),
        covered: ["delivery", event],
        missing: if(known?, do: [], else: ["event_mapping"])
      },
      limitations: ["webhook_delivery_not_provider_snapshot"],
      warnings: if(known?, do: [], else: ["unknown_event_type"])
    })
  end

  defp event_payload("repository", payload), do: Map.get(payload, "repository", %{})
  defp event_payload("issues", payload), do: Map.get(payload, "issue", %{})
  defp event_payload("pull_request", payload), do: Map.get(payload, "pull_request", %{})
  defp event_payload("check_run", payload), do: Map.get(payload, "check_run", %{})
  defp event_payload(_event, payload), do: payload

  defp event_kind("repository"), do: :repository
  defp event_kind("issues"), do: :issue
  defp event_kind("pull_request"), do: :pull_request
  defp event_kind("check_run"), do: :ci
  defp event_kind(_event), do: :webhook

  defp event_external_id("push", payload, _locator),
    do: to_string(Map.get(payload, "after") || Map.get(payload, "ref") || "unknown-push")

  defp event_external_id(_event, payload, locator) do
    to_string(Map.get(payload, "id") || Map.get(payload, "node_id") || locator.external_id)
  end

  defp normalize_event("push", payload, repository) do
    %{
      event: "push",
      ref: Map.get(payload, "ref"),
      before: Map.get(payload, "before"),
      after: Map.get(payload, "after"),
      forced: Map.get(payload, "forced", false),
      repository_id: Map.get(repository, "id")
    }
  end

  defp normalize_event("repository", payload, _repository) do
    Map.take(
      payload,
      ~w[id node_id name full_name default_branch visibility archived disabled fork]
    )
  end

  defp normalize_event("issues", payload, repository) do
    Map.take(payload, ~w[id node_id number state locked created_at updated_at closed_at])
    |> Map.put("repository_id", Map.get(repository, "id"))
  end

  defp normalize_event("pull_request", payload, repository) do
    Map.take(payload, ~w[id node_id number state draft merged created_at updated_at closed_at])
    |> Map.put("repository_id", Map.get(repository, "id"))
  end

  defp normalize_event("check_run", payload, repository) do
    Map.take(payload, ~w[id node_id name status conclusion started_at completed_at head_sha])
    |> Map.put("repository_id", Map.get(repository, "id"))
  end

  defp normalize_event(event, _payload, repository) do
    %{event: event, repository_id: Map.get(repository, "id")}
  end

  defp event_source_time(payload, repository) do
    (Map.get(payload, "updated_at") || Map.get(payload, "created_at") ||
       Map.get(repository, "updated_at"))
    |> parse_datetime()
  end

  defp bound_locator(payload, locator) do
    repository = Map.get(payload, "repository", payload)
    observed = Map.get(repository, "id")

    if not is_nil(observed) and to_string(observed) == locator.external_id,
      do: :ok,
      else: {:error, Error.new(:conflict, :webhook_locator_binding)}
  end

  defp verify_signature(body, "sha256=" <> encoded, secret)
       when is_binary(secret) and byte_size(secret) in 1..8_192 do
    with {:ok, provided} <- Base.decode16(encoded, case: :mixed),
         expected <- :crypto.mac(:hmac, :sha256, secret, body),
         true <- byte_size(provided) == byte_size(expected),
         true <- Plug.Crypto.secure_compare(provided, expected) do
      :ok
    else
      _invalid -> {:error, Error.new(:unauthorized, :webhook_signature)}
    end
  end

  defp verify_signature(_body, _signature, _secret),
    do: {:error, Error.new(:unauthorized, :webhook_signature)}

  defp decode_body(body) do
    case Jason.decode(body) do
      {:ok, payload} when is_map(payload) -> {:ok, payload}
      _invalid -> {:error, Error.new(:corrupt, :webhook_json)}
    end
  end

  defp active_enrollment(%{enrollment_iri: iri, admission: :allowed}) when is_binary(iri),
    do: :ok

  defp active_enrollment(%{admission: {:blocked, _state}}),
    do: {:error, Error.new(:conflict, :observation_enrollment_inactive)}

  defp active_enrollment(_enrollment), do: invalid(:observation_enrollment)

  defp valid_delivery_time(delivered_at, received_at) do
    age = DateTime.diff(received_at, delivered_at, :second)

    if age in -30..@max_delivery_age_seconds,
      do: :ok,
      else: {:error, Error.new(:unauthorized, :webhook_delivery_time)}
  end

  defp latest_source_time(observations) do
    observations
    |> Enum.map(& &1.source_time)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort({:desc, DateTime})
    |> List.first()
  end

  defp aggregate_completeness(observations) do
    statuses = Enum.map(observations, & &1.completeness.status)

    status =
      cond do
        Enum.all?(statuses, &(&1 == :complete)) -> :complete
        Enum.any?(statuses, &(&1 == :partial)) -> :partial
        true -> :unknown
      end

    %{
      status: status,
      covered:
        observations
        |> Enum.flat_map(& &1.completeness.covered)
        |> Enum.uniq(),
      missing:
        observations
        |> Enum.flat_map(& &1.completeness.missing)
        |> Enum.uniq()
    }
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, time, _offset} -> time
      _invalid -> nil
    end
  end

  defp parse_datetime(_value), do: nil

  defp valid_content_type?(value) when is_binary(value) do
    value |> String.downcase() |> String.split(";", parts: 2) |> List.first() ==
      "application/json"
  end

  defp valid_content_type?(_value), do: false

  defp valid_delivery_id?(value) do
    is_binary(value) and byte_size(value) in 1..256 and
      not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)
  end

  defp valid_event?(value) do
    is_binary(value) and byte_size(value) in 1..128 and Regex.match?(~r/^[A-Za-z0-9_.-]+$/, value)
  end

  defp digest(value) do
    value |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
