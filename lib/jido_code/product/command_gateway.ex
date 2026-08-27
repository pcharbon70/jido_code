defmodule JidoCode.Product.CommandGateway do
  @moduledoc """
  Server-owned constructor for finite product semantic intents.

  Browser input supplies workflow values only. Graph names, command types,
  revisions, actor identity, scope, and semantic resource identities are
  resolved here from trusted session context and current graph state.
  """

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.CommandReceipt
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.RepositoryWiki.GenerationProfile, as: WikiGenerationProfile
  alias JidoCode.Knowledge.Repositories.Enrollment
  alias JidoCode.Knowledge.Repositories.Locator
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Product.CommandOutcome
  alias JidoCode.Observability
  alias JidoCode.Security.Redactor

  @valid_to ~U[9999-12-31 23:59:59Z]
  @max_value_bytes 160
  @wiki_modes %{"off" => :off, "manual" => :manual, "automatic" => :automatic}
  @wiki_read_visibility %{"hidden" => :hidden, "retained" => :retained}

  @spec enroll_repository(AuthorityContext.t(), map(), map(), keyword()) ::
          {:ok, CommandOutcome.t()} | {:error, Error.t()}
  def enroll_repository(authority, identity, params, options \\ [])

  def enroll_repository(%AuthorityContext{} = authority, identity, params, options)
      when is_map(identity) and is_map(params) and is_list(options) do
    clock = Keyword.get(options, :clock, &DateTime.utc_now/0)
    summary = Keyword.get(options, :summary, &StoreServer.summary/0)
    metadata = Keyword.get(options, :metadata, &QueryRunner.graph_metadata/1)
    execute = Keyword.get(options, :execute, &Knowledge.execute/1)

    with :ok <-
           Redactor.reject_sensitive(
             Map.take(params, ~w[conceptual_key provider external_id owner name reason])
           ),
         {:ok, input} <- validate_input(params),
         true <- input.confirmed?,
         %DateTime{} = recorded_at <- clock.() |> DateTime.truncate(:microsecond),
         {:ok, catalog_graph} <- GraphRegistry.graph_iri(:factory_catalog, %{}),
         %{dataset_revision: dataset_revision} <- summary.(),
         true <- is_integer(dataset_revision) and dataset_revision >= 0,
         {:ok, %{graph_revision: catalog_revision}} <- metadata.(catalog_graph),
         {:ok, repository_iri} <- ResourceIdentity.conceptual_repository(input.conceptual_key),
         {:ok, repository_scope_iri} <- ResourceIdentity.scope(:repository, repository_iri),
         {:ok, locator} <- locator(input, recorded_at),
         {:ok, request_iri} <- request_iri(authority, input.idempotency_key),
         {:ok, enrollment} <-
           enrollment(
             authority,
             identity,
             input,
             locator,
             request_iri,
             repository_iri,
             repository_scope_iri,
             recorded_at
           ),
         {:ok, command} <-
           command(
             authority,
             identity,
             input,
             enrollment,
             request_iri,
             catalog_graph,
             dataset_revision,
             catalog_revision,
             recorded_at
           ),
         {:ok, %CommandReceipt{} = receipt} <-
           Observability.span(:command, Observability.correlation_ref(request_iri), fn ->
             execute.(command)
           end) do
      {:ok, CommandOutcome.from_receipt(receipt)}
    else
      false -> invalid(:enrollment_confirmation)
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:enroll_repository_intent)
    end
  rescue
    _error -> invalid(:enroll_repository_intent)
  catch
    :exit, _reason -> {:error, Error.new(:unavailable, :enroll_repository_intent)}
  end

  def enroll_repository(_authority, _identity, _params, _options),
    do: invalid(:enroll_repository_intent)

  @spec configure_repository_wiki(
          AuthorityContext.t(),
          map(),
          String.t(),
          map(),
          keyword()
        ) :: {:ok, CommandOutcome.t()} | {:error, Error.t()}
  def configure_repository_wiki(authority, identity, repository, params, options \\ [])

  def configure_repository_wiki(
        %AuthorityContext{} = authority,
        identity,
        repository,
        params,
        options
      )
      when is_map(identity) and is_binary(repository) and is_map(params) and is_list(options) do
    clock = Keyword.get(options, :clock, &DateTime.utc_now/0)
    summary = Keyword.get(options, :summary, &StoreServer.summary/0)
    metadata = Keyword.get(options, :metadata, &QueryRunner.graph_metadata/1)
    query = Keyword.get(options, :query, &Knowledge.query/6)
    execute = Keyword.get(options, :execute, &Knowledge.execute/1)

    with :ok <- Redactor.reject_sensitive(Map.take(params, ~w[mode read_visibility retention])),
         {:ok, input} <- wiki_input(params),
         true <- input.confirmed?,
         :ok <- ResourceIdentity.validate(repository),
         true <- authority.actor_iri == identity[:actor_iri],
         %DateTime{} = recorded_at <- clock.() |> DateTime.truncate(:microsecond),
         {:ok, catalog_graph} <- GraphRegistry.graph_iri(:factory_catalog, %{}),
         {:ok, control_graph} <-
           GraphRegistry.graph_iri(:repository_control, %{repository: repository}),
         %{dataset_revision: dataset_revision} <- summary.(),
         true <- is_integer(dataset_revision) and dataset_revision >= 0,
         {:ok, %{graph_revision: catalog_revision}} <- metadata.(catalog_graph),
         {:ok, %{graph_revision: control_revision}} <- metadata.(control_graph),
         {:ok, enrollment_result} <-
           query.(
             :repository_wiki_enrollment_detail,
             "2.10.0",
             %{graph: control_graph, resource: repository},
             authority,
             repository,
             []
           ),
         {:ok, resolution, tenant_iri} <- wiki_resolution(enrollment_result, repository, identity),
         {:ok, profile} <-
           wiki_profile(
             input.mode,
             authority,
             identity,
             catalog_graph,
             query,
             recorded_at
           ),
         {:ok, causation_iri} <-
           ResourceIdentity.deterministic(
             :command_request,
             Enum.join(
               [
                 authority.actor_iri,
                 repository,
                 Atom.to_string(input.mode),
                 Atom.to_string(input.read_visibility),
                 Integer.to_string(dataset_revision),
                 Integer.to_string(control_revision)
               ],
               "\n"
             )
           ),
         {:ok, command} <-
           Knowledge.transition_repository_wiki_enrollment(
             repository,
             tenant_iri,
             resolution,
             input.mode,
             %{
               catalog_graph_iri: catalog_graph,
               control_graph_iri: control_graph,
               expected_catalog_revision: catalog_revision,
               expected_control_revision: control_revision,
               expected_dataset_revision: dataset_revision,
               principal_iri: authority.principal_iri,
               actor_iri: authority.actor_iri,
               delegated_agent_iri: authority.delegated_agent_iri,
               delegation_iri: authority.delegation_iri,
               scope_iri: repository,
               correlation_iri: causation_iri,
               causation_iri: causation_iri,
               reason: "configure repository wiki from authenticated product",
               recorded_at: recorded_at,
               generation_profile: profile,
               read_visibility: input.read_visibility
             },
             clock: fn -> recorded_at end
           ),
         {:ok, %CommandReceipt{} = receipt} <- execute.(command) do
      {:ok, CommandOutcome.from_receipt(receipt)}
    else
      false -> invalid(:repository_wiki_settings_confirmation)
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:configure_repository_wiki_intent)
    end
  rescue
    _error -> invalid(:configure_repository_wiki_intent)
  catch
    :exit, _reason -> {:error, Error.new(:unavailable, :configure_repository_wiki_intent)}
  end

  def configure_repository_wiki(_authority, _identity, _repository, _params, _options),
    do: invalid(:configure_repository_wiki_intent)

  @spec regenerate_repository_wiki(AuthorityContext.t(), map(), String.t(), keyword()) ::
          {:ok, CommandOutcome.t()} | {:error, Error.t()}
  def regenerate_repository_wiki(authority, identity, repository, options \\ [])

  def regenerate_repository_wiki(
        %AuthorityContext{} = authority,
        identity,
        repository,
        options
      )
      when is_map(identity) and is_binary(repository) and is_list(options) do
    requester = Keyword.get(options, :requester)

    with true <- authority.actor_iri == identity[:actor_iri],
         :ok <- ResourceIdentity.validate(repository),
         true <- is_function(requester, 3) do
      requester.(authority, repository, :manual_deterministic)
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:unavailable, :regenerate_repository_wiki_intent)}
    end
  end

  def regenerate_repository_wiki(_authority, _identity, _repository, _options),
    do: invalid(:regenerate_repository_wiki_intent)

  defp enrollment(
         authority,
         identity,
         input,
         locator,
         request_iri,
         repository_iri,
         repository_scope_iri,
         recorded_at
       ) do
    Enrollment.new(%{
      factory_iri: identity.factory_iri,
      repository_iri: repository_iri,
      repository_scope_iri: repository_scope_iri,
      policy_boundary_iri: identity.policy_boundary_iri,
      policy_iris: identity.policy_iris,
      locator: locator,
      actor_iri: authority.actor_iri,
      cause_iri: request_iri,
      reason: input.reason,
      valid_from: recorded_at,
      valid_to: @valid_to,
      initial_state: :active
    })
  end

  defp command(
         authority,
         identity,
         input,
         enrollment,
         request_iri,
         catalog_graph,
         dataset_revision,
         catalog_revision,
         recorded_at
       ) do
    Enrollment.enroll_command(
      enrollment,
      %{
        command_iri: request_iri,
        principal_iri: authority.principal_iri,
        delegated_agent_iri: authority.delegated_agent_iri,
        delegation_iri: authority.delegation_iri,
        factory_scope_iri: identity.factory_scope_iri,
        idempotency_key: input.idempotency_key,
        correlation_iri: request_iri,
        causation_iri: request_iri,
        expected_dataset_revision: dataset_revision,
        catalog_graph_iri: catalog_graph,
        expected_catalog_revision: catalog_revision,
        reason: input.reason
      },
      clock: fn -> recorded_at end
    )
  end

  defp request_iri(authority, idempotency_key) do
    ResourceIdentity.deterministic(
      :command_request,
      Enum.join([authority.actor_iri, "enroll-repository", idempotency_key], "\n")
    )
  end

  defp wiki_input(params) do
    with {:ok, mode} <- Map.fetch(@wiki_modes, params["mode"]),
         {:ok, visibility} <- Map.fetch(@wiki_read_visibility, params["read_visibility"]),
         true <- params["retention"] == "standard" do
      {:ok,
       %{
         mode: mode,
         read_visibility: visibility,
         retention: :standard,
         confirmed?: params["confirmed"] in ["true", true]
       }}
    else
      _invalid -> invalid(:repository_wiki_settings_form)
    end
  end

  defp wiki_resolution(%QueryResult{} = result, repository, identity) do
    case result.data do
      [] ->
        {:ok, nil, identity.policy_boundary_iri}

      [row] ->
        with tenant when is_binary(tenant) <- query_value(row, "tenant"),
             enrollment when is_binary(enrollment) <- query_value(row, "enrollment"),
             transition when is_binary(transition) <- query_value(row, "transition"),
             revision when is_integer(revision) <- query_integer(row, "revision"),
             state when state in [:off, :manual, :automatic] <-
               query_concept(row, "state", [:off, :manual, :automatic]),
             :ok <- ResourceIdentity.validate(tenant),
             :ok <- ResourceIdentity.validate(enrollment),
             :ok <- ResourceIdentity.validate(transition) do
          {:ok,
           %{
             repository_iri: repository,
             tenant_iri: tenant,
             current_state: state,
             current_revision: revision,
             current_enrollment_iri: enrollment,
             current_transition_iri: transition,
             cancellation_generation: query_integer(row, "cancellationGeneration") || 0,
             current_edition_iri: query_value(row, "currentEdition")
           }, tenant}
        else
          {:error, %Error{} = error} -> {:error, error}
          _invalid -> invalid(:repository_wiki_settings_resolution)
        end

      _invalid ->
        invalid(:repository_wiki_settings_resolution)
    end
  end

  defp wiki_resolution(_result, _repository, _identity),
    do: invalid(:repository_wiki_settings_resolution)

  defp wiki_profile(:off, _authority, _identity, _graph, _query, _recorded_at),
    do: {:ok, nil}

  defp wiki_profile(mode, authority, identity, graph, query, recorded_at)
       when mode in [:manual, :automatic] do
    key = if(mode == :manual, do: :manual_deterministic, else: :automatic_deterministic)

    with {:ok, %QueryResult{} = result} <-
           query.(
             :repository_wiki_generation_profiles,
             "2.10.0",
             %{graph: graph},
             authority,
             identity.factory_scope_iri,
             []
           ),
         row when is_map(row) <-
           Enum.find(result.data, &(query_value(&1, "profileKey") == Atom.to_string(key))),
         approved_at when is_binary(approved_at) <- query_value(row, "approved"),
         {:ok, approved, _offset} <- DateTime.from_iso8601(approved_at),
         {:ok, expires} <- optional_datetime(query_value(row, "expires")),
         {:ok, %WikiGenerationProfile{} = profile} <-
           WikiGenerationProfile.new(key, %{approved_at: approved, expires_at: expires}),
         true <- profile.iri == query_value(row, "profile"),
         true <- profile.compiler_digest == query_value(row, "compilerDigest"),
         true <- profile.compiler_profile == query_value(row, "compilerProfile"),
         true <- DateTime.compare(profile.approved_at, recorded_at) in [:lt, :eq] do
      {:ok, profile}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_settings_profile)
    end
  end

  defp optional_datetime(nil), do: {:ok, nil}

  defp optional_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      _invalid -> invalid(:repository_wiki_settings_profile)
    end
  end

  defp optional_datetime(_value), do: invalid(:repository_wiki_settings_profile)

  defp query_value(row, key) when is_map(row) do
    case Map.get(row, key) do
      %{value: value} -> query_scalar(value)
      value -> query_scalar(value)
    end
  end

  defp query_scalar(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp query_scalar(value) when is_binary(value) or is_integer(value), do: value
  defp query_scalar(_value), do: nil

  defp query_integer(row, key) do
    case query_value(row, key) do
      value when is_integer(value) ->
        value

      value when is_binary(value) ->
        case Integer.parse(value) do
          {number, ""} -> number
          _invalid -> nil
        end

      _value ->
        nil
    end
  end

  defp query_concept(row, key, allowed) do
    value = query_value(row, key) || ""
    Enum.find(allowed, &String.ends_with?(String.downcase(value), Atom.to_string(&1)))
  end

  defp validate_input(params) do
    with {:ok, conceptual_key} <- value(params, "conceptual_key"),
         {:ok, provider} <- value(params, "provider"),
         {:ok, external_id} <- value(params, "external_id"),
         {:ok, owner} <- value(params, "owner"),
         {:ok, name} <- value(params, "name"),
         {:ok, reason} <- value(params, "reason"),
         {:ok, idempotency_key} <- idempotency(params["idempotency_key"]),
         confirmed? <- params["confirmed"] in ["true", true] do
      {:ok,
       %{
         conceptual_key: conceptual_key,
         provider: provider,
         external_id: external_id,
         owner: owner,
         name: name,
         reason: reason,
         idempotency_key: idempotency_key,
         confirmed?: confirmed?
       }}
    end
  end

  defp value(params, key) do
    case params[key] do
      value when is_binary(value) ->
        value = String.trim(value)

        if value != "" and byte_size(value) <= @max_value_bytes,
          do: {:ok, value},
          else: invalid(:enrollment_form)

      _invalid ->
        invalid(:enrollment_form)
    end
  end

  defp idempotency(value) when is_binary(value) do
    if byte_size(value) in 16..96 and Regex.match?(~r/^[A-Za-z0-9_-]+$/, value),
      do: {:ok, value},
      else: invalid(:enrollment_idempotency)
  end

  defp idempotency(_value), do: invalid(:enrollment_idempotency)

  defp locator(input, recorded_at) do
    Locator.new(%{
      provider: input.provider,
      external_id: input.external_id,
      owner: input.owner,
      name: input.name,
      state: :active,
      observed_at: recorded_at,
      relationships: []
    })
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
