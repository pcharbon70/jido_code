defmodule JidoCode.GitHub.WebhookPipeline do
  @moduledoc """
  Routes verified webhook deliveries into downstream pipeline stages.
  """

  require Logger

  alias JidoCode.GitHub.Repo
  alias JidoCode.GitHub.WebhookDelivery

  @type verified_delivery :: %{
          delivery_id: String.t() | nil,
          event: String.t() | nil,
          payload: map(),
          raw_payload: binary()
        }

  @type dispatch_decision :: :dispatch | :duplicate

  @spec route_verified_delivery(verified_delivery()) :: :ok | {:error, :verified_dispatch_failed}
  def route_verified_delivery(%{} = delivery) do
    with {:ok, dispatch_decision} <- persist_delivery_for_idempotency(delivery) do
      case dispatch_decision do
        :dispatch ->
          dispatch_verified_delivery(delivery)

        :duplicate ->
          :ok
      end
    else
      {:error, reason} ->
        Logger.error(
          "github_webhook_delivery_persist_failed reason=#{inspect(reason)} delivery_id=#{log_value(Map.get(delivery, :delivery_id))} event=#{log_value(Map.get(delivery, :event))}"
        )

        {:error, :verified_dispatch_failed}
    end
  end

  @doc false
  @spec default_dispatcher(verified_delivery()) :: :ok
  def default_dispatcher(%{} = delivery) do
    Logger.info(
      "github_webhook_pipeline_handoff stage=idempotency stage_next=trigger_mapping delivery_id=#{log_value(Map.get(delivery, :delivery_id))} event=#{log_value(Map.get(delivery, :event))}"
    )

    :ok
  end

  @spec persist_delivery_for_idempotency(verified_delivery()) ::
          {:ok, dispatch_decision()} | {:error, term()}
  defp persist_delivery_for_idempotency(%{} = delivery) do
    with {:ok, delivery_id} <- normalize_required_string(Map.get(delivery, :delivery_id), :missing_delivery_id),
         {:ok, existing_delivery} <- get_delivery_by_id(delivery_id),
         {:ok, dispatch_decision} <-
           persist_or_acknowledge_duplicate(existing_delivery, delivery, delivery_id) do
      {:ok, dispatch_decision}
    end
  end

  @spec persist_or_acknowledge_duplicate(WebhookDelivery.t() | nil, verified_delivery(), String.t()) ::
          {:ok, dispatch_decision()} | {:error, term()}
  defp persist_or_acknowledge_duplicate(%WebhookDelivery{}, delivery, delivery_id) do
    log_duplicate_delivery_ack(delivery_id, Map.get(delivery, :event))
    {:ok, :duplicate}
  end

  defp persist_or_acknowledge_duplicate(nil, delivery, delivery_id) do
    with {:ok, event} <- normalize_required_string(Map.get(delivery, :event), :missing_event),
         {:ok, payload} <- normalize_payload(Map.get(delivery, :payload)),
         {:ok, repo_id} <- resolve_repo_id(payload),
         {:ok, dispatch_decision} <- create_delivery_record(delivery_id, event, payload, repo_id) do
      {:ok, dispatch_decision}
    end
  end

  @spec create_delivery_record(String.t(), String.t(), map(), Ash.UUID.t()) ::
          {:ok, dispatch_decision()} | {:error, term()}
  defp create_delivery_record(delivery_id, event, payload, repo_id) do
    case WebhookDelivery.create(
           %{
             github_delivery_id: delivery_id,
             event_type: event,
             action: normalize_action(payload),
             payload: payload,
             repo_id: repo_id
           },
           authorize?: false
         ) do
      {:ok, %WebhookDelivery{}} ->
        Logger.info(
          "github_webhook_delivery_persisted outcome=recorded delivery_id=#{delivery_id} event=#{event} repo_id=#{repo_id}"
        )

        {:ok, :dispatch}

      {:error, reason} ->
        resolve_delivery_create_error(delivery_id, event, reason)
    end
  end

  @spec resolve_delivery_create_error(String.t(), String.t(), term()) ::
          {:ok, dispatch_decision()} | {:error, term()}
  defp resolve_delivery_create_error(delivery_id, event, reason) do
    case get_delivery_by_id(delivery_id) do
      {:ok, %WebhookDelivery{}} ->
        log_duplicate_delivery_ack(delivery_id, event)
        {:ok, :duplicate}

      {:ok, nil} ->
        {:error, {:delivery_persist_failed, reason}}

      {:error, lookup_reason} ->
        {:error, {:delivery_persist_failed, {reason, lookup_reason}}}
    end
  end

  @spec get_delivery_by_id(String.t()) :: {:ok, WebhookDelivery.t() | nil} | {:error, term()}
  defp get_delivery_by_id(delivery_id) when is_binary(delivery_id) do
    case WebhookDelivery.get_by_github_delivery_id(delivery_id, authorize?: false) do
      {:ok, %WebhookDelivery{} = delivery} ->
        {:ok, delivery}

      {:ok, nil} ->
        {:ok, nil}

      {:error, reason} ->
        if ash_not_found?(reason) do
          {:ok, nil}
        else
          {:error, reason}
        end
    end
  end

  @spec resolve_repo_id(map()) :: {:ok, Ash.UUID.t()} | {:error, term()}
  defp resolve_repo_id(payload) when is_map(payload) do
    with {:ok, repo_full_name} <- extract_repo_full_name(payload),
         {:ok, %Repo{id: repo_id}} <- get_repo_by_full_name(repo_full_name) do
      {:ok, repo_id}
    end
  end

  @spec extract_repo_full_name(map()) :: {:ok, String.t()} | {:error, :missing_repository_full_name}
  defp extract_repo_full_name(payload) when is_map(payload) do
    repository =
      Map.get(payload, "repository") ||
        Map.get(payload, :repository)

    full_name =
      case repository do
        %{} = repository_map ->
          Map.get(repository_map, "full_name") || Map.get(repository_map, :full_name)

        _other ->
          nil
      end

    normalize_required_string(full_name, :missing_repository_full_name)
  end

  @spec get_repo_by_full_name(String.t()) :: {:ok, Repo.t()} | {:error, term()}
  defp get_repo_by_full_name(repo_full_name) when is_binary(repo_full_name) do
    case Repo.get_by_full_name(repo_full_name, authorize?: false) do
      {:ok, %Repo{} = repo} ->
        {:ok, repo}

      {:ok, nil} ->
        {:error, :repo_not_found}

      {:error, reason} ->
        if ash_not_found?(reason) do
          {:error, :repo_not_found}
        else
          {:error, {:repo_lookup_failed, reason}}
        end
    end
  end

  @spec normalize_action(map()) :: String.t() | nil
  defp normalize_action(payload) when is_map(payload) do
    case Map.get(payload, "action") || Map.get(payload, :action) do
      action when is_binary(action) ->
        case String.trim(action) do
          "" -> nil
          normalized_action -> normalized_action
        end

      _other ->
        nil
    end
  end

  @spec normalize_payload(term()) :: {:ok, map()} | {:error, :missing_payload}
  defp normalize_payload(payload) when is_map(payload), do: {:ok, payload}
  defp normalize_payload(_payload), do: {:error, :missing_payload}

  @spec normalize_required_string(term(), term()) :: {:ok, String.t()} | {:error, term()}
  defp normalize_required_string(value, error_reason) when is_binary(value) do
    case String.trim(value) do
      "" -> {:error, error_reason}
      normalized_value -> {:ok, normalized_value}
    end
  end

  defp normalize_required_string(_value, error_reason), do: {:error, error_reason}

  @spec log_duplicate_delivery_ack(String.t(), String.t() | nil) :: :ok
  defp log_duplicate_delivery_ack(delivery_id, event) do
    Logger.info(
      "github_webhook_delivery_persisted outcome=duplicate_acknowledged delivery_id=#{delivery_id} event=#{log_value(event)}"
    )

    :ok
  end

  @spec ash_not_found?(term()) :: boolean()
  defp ash_not_found?(%Ash.Error.Query.NotFound{}), do: true

  defp ash_not_found?(%Ash.Error.Invalid{errors: errors}) when is_list(errors) do
    Enum.any?(errors, &ash_not_found?/1)
  end

  defp ash_not_found?(%{errors: errors}) when is_list(errors) do
    Enum.any?(errors, &ash_not_found?/1)
  end

  defp ash_not_found?(_reason), do: false

  defp dispatch_verified_delivery(delivery) do
    dispatcher =
      Application.get_env(
        :jido_code,
        :github_webhook_verified_dispatcher,
        &__MODULE__.default_dispatcher/1
      )

    case safe_dispatch(dispatcher, delivery) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error(
          "github_webhook_pipeline_dispatch_failed reason=#{inspect(reason)} delivery_id=#{log_value(Map.get(delivery, :delivery_id))} event=#{log_value(Map.get(delivery, :event))}"
        )

        {:error, :verified_dispatch_failed}
    end
  end

  defp safe_dispatch(dispatcher, delivery) when is_function(dispatcher, 1) do
    try do
      case dispatcher.(delivery) do
        :ok -> :ok
        {:ok, _result} -> :ok
        {:error, reason} -> {:error, reason}
        other -> {:error, {:unexpected_dispatch_result, other}}
      end
    rescue
      exception ->
        {:error, {:dispatch_exception, Exception.message(exception)}}
    catch
      kind, reason ->
        {:error, {:dispatch_throw, {kind, reason}}}
    end
  end

  defp safe_dispatch(_dispatcher, _delivery), do: {:error, :invalid_dispatcher}

  defp log_value(value) when is_binary(value) and value != "", do: value
  defp log_value(_value), do: "unknown"
end
