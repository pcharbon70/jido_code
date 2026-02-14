defmodule JidoCode.Setup.WebhookSimulationChecks do
  @moduledoc """
  Runs setup step 6 webhook simulation checks before Issue Bot defaults are enabled.
  """

  @default_checker_remediation "Verify webhook simulation checker configuration and retry setup."
  @default_signature_remediation "Configure `GITHUB_WEBHOOK_SECRET` and retry webhook simulation."
  @default_routing_remediation "Configure Issue Bot webhook routing for this event and retry simulation."
  @default_issue_bot_defaults %{"enabled" => true, "approval_mode" => "manual"}
  @default_events ["issues.opened", "issues.edited", "issue_comment.created"]

  @type status :: :ready | :blocked
  @type check_status :: :ready | :failed

  @type signature_result :: %{
          status: check_status(),
          previous_status: check_status(),
          transition: String.t(),
          detail: String.t(),
          remediation: String.t(),
          checked_at: DateTime.t()
        }

  @type event_result :: %{
          event: String.t(),
          route: String.t(),
          status: check_status(),
          previous_status: check_status(),
          transition: String.t(),
          detail: String.t(),
          remediation: String.t(),
          checked_at: DateTime.t()
        }

  @type report :: %{
          checked_at: DateTime.t(),
          status: status(),
          signature: signature_result(),
          events: [event_result()],
          failure_reason: String.t() | nil,
          issue_bot_defaults: map() | nil
        }

  @spec run(map() | nil) :: report()
  def run(previous_state \\ nil) do
    checked_at = DateTime.utc_now() |> DateTime.truncate(:second)
    previous_report = from_state(previous_state)
    previous_signature_status = previous_signature_status(previous_report)
    previous_event_statuses = previous_event_statuses(previous_report)

    checker =
      Application.get_env(
        :jido_code,
        :setup_webhook_simulation_checker,
        &__MODULE__.default_checker/1
      )

    checker
    |> safe_invoke_checker(%{
      checked_at: checked_at,
      previous_signature_status: previous_signature_status,
      previous_event_statuses: previous_event_statuses
    })
    |> normalize_report(checked_at, previous_signature_status, previous_event_statuses)
  end

  @spec blocked?(report()) :: boolean()
  def blocked?(%{status: :ready}), do: false
  def blocked?(%{status: _status}), do: true
  def blocked?(_), do: true

  @spec failure_reason(report()) :: String.t() | nil
  def failure_reason(%{failure_reason: failure_reason}) when is_binary(failure_reason) and failure_reason != "",
    do: failure_reason

  def failure_reason(_report), do: nil

  @spec issue_bot_defaults(report()) :: map()
  def issue_bot_defaults(%{status: :ready, issue_bot_defaults: issue_bot_defaults}) when is_map(issue_bot_defaults) do
    issue_bot_defaults
  end

  def issue_bot_defaults(_report), do: %{}

  @spec serialize_for_state(report()) :: map()
  def serialize_for_state(%{
        checked_at: checked_at,
        status: status,
        signature: signature,
        events: events,
        failure_reason: failure_reason,
        issue_bot_defaults: issue_bot_defaults
      })
      when is_map(signature) and is_list(events) do
    %{
      "checked_at" => DateTime.to_iso8601(checked_at),
      "status" => Atom.to_string(status),
      "signature" => %{
        "status" => Atom.to_string(signature.status),
        "previous_status" => Atom.to_string(signature.previous_status),
        "transition" => signature.transition,
        "detail" => signature.detail,
        "remediation" => signature.remediation,
        "checked_at" => DateTime.to_iso8601(signature.checked_at)
      },
      "events" =>
        Enum.map(events, fn event_result ->
          %{
            "event" => event_result.event,
            "route" => event_result.route,
            "status" => Atom.to_string(event_result.status),
            "previous_status" => Atom.to_string(event_result.previous_status),
            "transition" => event_result.transition,
            "detail" => event_result.detail,
            "remediation" => event_result.remediation,
            "checked_at" => DateTime.to_iso8601(event_result.checked_at)
          }
        end),
      "failure_reason" => failure_reason,
      "issue_bot_defaults" => issue_bot_defaults
    }
  end

  def serialize_for_state(_), do: %{}

  @spec from_state(map() | nil) :: report() | nil
  def from_state(nil), do: nil

  def from_state(state) when is_map(state) do
    checked_at =
      state
      |> map_get(:checked_at, "checked_at")
      |> normalize_checked_at(DateTime.utc_now() |> DateTime.truncate(:second))

    signature =
      state
      |> map_get(:signature, "signature", %{})
      |> normalize_signature_result(checked_at, :failed)

    events =
      state
      |> map_get(:events, "events", [])
      |> normalize_event_results(checked_at, %{})

    if events == [] do
      nil
    else
      status = overall_status(signature, events)

      %{
        checked_at: checked_at,
        signature: signature,
        events: events,
        status:
          state
          |> map_get(:status, "status", nil)
          |> normalize_status(status),
        failure_reason:
          state
          |> map_get(:failure_reason, "failure_reason", nil)
          |> normalize_failure_reason(signature, events),
        issue_bot_defaults:
          state
          |> map_get(:issue_bot_defaults, "issue_bot_defaults", nil)
          |> normalize_issue_bot_defaults(status)
      }
    end
  end

  def from_state(_), do: nil

  @doc false
  def default_checker(%{
        checked_at: checked_at,
        previous_signature_status: previous_signature_status,
        previous_event_statuses: previous_event_statuses
      })
      when is_map(previous_event_statuses) do
    signature_status = if webhook_secret_present?(), do: :ready, else: :failed

    signature =
      %{
        status: signature_status,
        previous_status: previous_signature_status,
        transition: transition_label(previous_signature_status, signature_status),
        detail: default_signature_detail(signature_status),
        remediation: default_signature_remediation(signature_status),
        checked_at: checked_at
      }

    events =
      configured_events()
      |> Enum.map(fn event ->
        previous_status = Map.get(previous_event_statuses, event, :failed)
        route = route_for_event(event)
        event_status = if is_binary(route), do: :ready, else: :failed

        %{
          event: event,
          route: route || "Unconfigured event route",
          status: event_status,
          previous_status: previous_status,
          transition: transition_label(previous_status, event_status),
          detail: default_event_detail(event, event_status),
          remediation: default_event_remediation(event_status),
          checked_at: checked_at
        }
      end)

    status = overall_status(signature, events)

    %{
      checked_at: checked_at,
      status: status,
      signature: signature,
      events: events,
      failure_reason: default_failure_reason(signature, events),
      issue_bot_defaults: normalize_issue_bot_defaults(@default_issue_bot_defaults, status)
    }
  end

  defp safe_invoke_checker(checker, context) when is_function(checker, 1) do
    try do
      checker.(context)
    rescue
      exception ->
        {:error, {:checker_exception, Exception.message(exception)}}
    catch
      kind, reason ->
        {:error, {:checker_throw, {kind, reason}}}
    end
  end

  defp safe_invoke_checker(_checker, _context), do: {:error, :invalid_checker}

  defp normalize_report(
         %{signature: signature, events: events} = report,
         default_checked_at,
         previous_signature_status,
         previous_event_statuses
       )
       when is_map(signature) and is_list(events) do
    checked_at =
      report
      |> map_get(:checked_at, "checked_at")
      |> normalize_checked_at(default_checked_at)

    normalized_signature =
      normalize_signature_result(signature, checked_at, previous_signature_status)

    normalized_events =
      normalize_event_results(events, checked_at, previous_event_statuses)

    default_status = overall_status(normalized_signature, normalized_events)

    status =
      report
      |> map_get(:status, "status", nil)
      |> normalize_status(default_status)

    %{
      checked_at: checked_at,
      signature: normalized_signature,
      events: normalized_events,
      status: status,
      failure_reason:
        report
        |> map_get(:failure_reason, "failure_reason", nil)
        |> normalize_failure_reason(normalized_signature, normalized_events),
      issue_bot_defaults:
        report
        |> map_get(:issue_bot_defaults, "issue_bot_defaults", nil)
        |> normalize_issue_bot_defaults(status)
    }
  end

  defp normalize_report(report, default_checked_at, previous_signature_status, previous_event_statuses)
       when is_map(report) do
    normalize_report(
      %{
        checked_at: map_get(report, :checked_at, "checked_at", default_checked_at),
        signature: map_get(report, :signature, "signature", %{}),
        events: map_get(report, :events, "events", [])
      },
      default_checked_at,
      previous_signature_status,
      previous_event_statuses
    )
  end

  defp normalize_report(
         {:error, reason},
         default_checked_at,
         previous_signature_status,
         previous_event_statuses
       ) do
    checker_error_report(
      reason,
      default_checked_at,
      previous_signature_status,
      previous_event_statuses
    )
  end

  defp normalize_report(
         other,
         default_checked_at,
         previous_signature_status,
         previous_event_statuses
       ) do
    checker_error_report(
      {:invalid_checker_result, other},
      default_checked_at,
      previous_signature_status,
      previous_event_statuses
    )
  end

  defp checker_error_report(reason, checked_at, previous_signature_status, previous_event_statuses) do
    signature =
      normalize_signature_result(
        %{
          status: :failed,
          previous_status: previous_signature_status,
          detail: "Webhook signature simulation failed: #{inspect(reason)}",
          remediation: @default_checker_remediation,
          checked_at: checked_at
        },
        checked_at,
        previous_signature_status
      )

    events =
      configured_events()
      |> Enum.map(fn event ->
        previous_status = Map.get(previous_event_statuses, event, :failed)

        normalize_event_result(
          %{
            event: event,
            route: route_for_event(event) || "Unconfigured event route",
            status: :failed,
            previous_status: previous_status,
            detail: "Webhook event simulation failed: #{inspect(reason)}",
            remediation: @default_checker_remediation,
            checked_at: checked_at
          },
          checked_at,
          previous_status
        )
      end)

    %{
      checked_at: checked_at,
      status: :blocked,
      signature: signature,
      events: events,
      failure_reason: default_failure_reason(signature, events),
      issue_bot_defaults: nil
    }
  end

  defp normalize_signature_result(signature, default_checked_at, previous_signature_status)
       when is_map(signature) do
    status = signature |> map_get(:status, "status", nil) |> normalize_check_status(:failed)

    previous_status =
      signature
      |> map_get(:previous_status, "previous_status", previous_signature_status)
      |> normalize_check_status(previous_signature_status)

    %{
      status: status,
      previous_status: previous_status,
      transition:
        signature
        |> map_get(:transition, "transition", nil)
        |> normalize_text(transition_label(previous_status, status)),
      detail:
        signature
        |> map_get(:detail, "detail", nil)
        |> normalize_text(default_signature_detail(status)),
      remediation:
        signature
        |> map_get(:remediation, "remediation", nil)
        |> normalize_text(default_signature_remediation(status)),
      checked_at:
        signature
        |> map_get(:checked_at, "checked_at")
        |> normalize_checked_at(default_checked_at)
    }
  end

  defp normalize_signature_result(_signature, default_checked_at, previous_signature_status) do
    normalize_signature_result(
      %{
        status: :failed,
        previous_status: previous_signature_status,
        detail: "Webhook signature simulation produced an invalid result.",
        remediation: @default_checker_remediation,
        checked_at: default_checked_at
      },
      default_checked_at,
      previous_signature_status
    )
  end

  defp normalize_event_results(events, checked_at, previous_event_statuses) when is_list(events) do
    events
    |> Enum.with_index()
    |> Enum.map(fn {event_result, index} ->
      event_name =
        event_result
        |> map_get(:event, "event", Enum.at(@default_events, index))
        |> normalize_event_name(Enum.at(@default_events, index))

      previous_status = Map.get(previous_event_statuses, event_name, :failed)

      normalize_event_result(event_result, checked_at, previous_status)
    end)
  end

  defp normalize_event_results(_events, checked_at, previous_event_statuses) do
    @default_events
    |> Enum.map(fn event ->
      previous_status = Map.get(previous_event_statuses, event, :failed)

      normalize_event_result(
        %{
          event: event,
          route: route_for_event(event) || "Unconfigured event route",
          status: :failed,
          previous_status: previous_status,
          detail: "Webhook event simulation produced an invalid result.",
          remediation: @default_checker_remediation,
          checked_at: checked_at
        },
        checked_at,
        previous_status
      )
    end)
  end

  defp normalize_event_result(event_result, default_checked_at, previous_event_status)
       when is_map(event_result) do
    event =
      event_result
      |> map_get(:event, "event", nil)
      |> normalize_event_name(default_event_name())

    status = event_result |> map_get(:status, "status", nil) |> normalize_check_status(:failed)

    previous_status =
      event_result
      |> map_get(:previous_status, "previous_status", previous_event_status)
      |> normalize_check_status(previous_event_status)

    %{
      event: event,
      route:
        event_result
        |> map_get(:route, "route", route_for_event(event) || "Unconfigured event route")
        |> normalize_text(route_for_event(event) || "Unconfigured event route"),
      status: status,
      previous_status: previous_status,
      transition:
        event_result
        |> map_get(:transition, "transition", nil)
        |> normalize_text(transition_label(previous_status, status)),
      detail:
        event_result
        |> map_get(:detail, "detail", nil)
        |> normalize_text(default_event_detail(event, status)),
      remediation:
        event_result
        |> map_get(:remediation, "remediation", nil)
        |> normalize_text(default_event_remediation(status)),
      checked_at:
        event_result
        |> map_get(:checked_at, "checked_at")
        |> normalize_checked_at(default_checked_at)
    }
  end

  defp normalize_event_result(_event_result, default_checked_at, previous_event_status) do
    normalize_event_result(
      %{
        event: default_event_name(),
        route: "Unconfigured event route",
        status: :failed,
        previous_status: previous_event_status,
        detail: "Webhook event simulation produced an invalid result.",
        remediation: @default_checker_remediation,
        checked_at: default_checked_at
      },
      default_checked_at,
      previous_event_status
    )
  end

  defp normalize_status(:ready, _default), do: :ready
  defp normalize_status(:blocked, _default), do: :blocked
  defp normalize_status("ready", _default), do: :ready
  defp normalize_status("blocked", _default), do: :blocked
  defp normalize_status(_status, default), do: default

  defp normalize_check_status(:ready, _default), do: :ready
  defp normalize_check_status(:failed, _default), do: :failed
  defp normalize_check_status("ready", _default), do: :ready
  defp normalize_check_status("failed", _default), do: :failed
  defp normalize_check_status(_status, default), do: default

  defp normalize_checked_at(%DateTime{} = checked_at, _default), do: checked_at

  defp normalize_checked_at(checked_at, default) when is_binary(checked_at) do
    case DateTime.from_iso8601(checked_at) do
      {:ok, parsed_checked_at, _offset} -> parsed_checked_at
      {:error, _reason} -> default
    end
  end

  defp normalize_checked_at(_checked_at, default), do: default

  defp normalize_text(value, _fallback) when is_binary(value) and value != "" do
    String.trim(value)
  end

  defp normalize_text(_value, fallback), do: fallback

  defp normalize_event_name(value, fallback) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> fallback || default_event_name()
      normalized_event -> normalized_event
    end
  end

  defp normalize_event_name(value, fallback) when is_atom(value) do
    value
    |> Atom.to_string()
    |> normalize_event_name(fallback)
  end

  defp normalize_event_name(nil, fallback), do: fallback || default_event_name()
  defp normalize_event_name(_value, fallback), do: fallback || default_event_name()

  defp normalize_failure_reason(failure_reason, _signature, _events)
       when is_binary(failure_reason) and failure_reason != "" do
    String.trim(failure_reason)
  end

  defp normalize_failure_reason(_failure_reason, signature, events) do
    default_failure_reason(signature, events)
  end

  defp normalize_issue_bot_defaults(issue_bot_defaults, :ready) when is_map(issue_bot_defaults) do
    enabled =
      issue_bot_defaults
      |> map_get(:enabled, "enabled", true)
      |> normalize_enabled(true)

    approval_mode =
      issue_bot_defaults
      |> map_get(:approval_mode, "approval_mode", "manual")
      |> normalize_approval_mode("manual")

    %{
      "enabled" => enabled,
      "approval_mode" => approval_mode
    }
  end

  defp normalize_issue_bot_defaults(_issue_bot_defaults, :ready), do: @default_issue_bot_defaults
  defp normalize_issue_bot_defaults(_issue_bot_defaults, _status), do: nil

  defp normalize_enabled(true, _default), do: true
  defp normalize_enabled(false, _default), do: false
  defp normalize_enabled("true", _default), do: true
  defp normalize_enabled("false", _default), do: false
  defp normalize_enabled(_enabled, default), do: default

  defp normalize_approval_mode(value, _default) when is_binary(value) and value != "" do
    String.trim(value)
  end

  defp normalize_approval_mode(value, default) when is_atom(value) do
    value
    |> Atom.to_string()
    |> normalize_approval_mode(default)
  end

  defp normalize_approval_mode(_value, default), do: default

  defp default_failure_reason(signature, events) do
    cond do
      signature.status != :ready ->
        signature.detail

      true ->
        failed_events =
          events
          |> Enum.filter(fn event_result -> event_result.status != :ready end)
          |> Enum.map(fn event_result -> event_result.event end)

        case failed_events do
          [] -> nil
          _events -> "Routing readiness failed for events: #{Enum.join(failed_events, ", ")}."
        end
    end
  end

  defp default_signature_detail(:ready) do
    "Webhook signature verification is ready for simulated deliveries."
  end

  defp default_signature_detail(:failed) do
    "Webhook signature verification is blocked because the webhook secret is not configured."
  end

  defp default_signature_remediation(:ready), do: "Signature readiness confirmed."
  defp default_signature_remediation(:failed), do: @default_signature_remediation

  defp default_event_detail(event, :ready) do
    "Webhook routing is ready for `#{event}`."
  end

  defp default_event_detail(event, :failed) do
    "Webhook routing is not configured for `#{event}`."
  end

  defp default_event_remediation(:ready), do: "Routing readiness confirmed."
  defp default_event_remediation(:failed), do: @default_routing_remediation

  defp overall_status(signature, events) do
    if signature.status == :ready and Enum.all?(events, fn event_result -> event_result.status == :ready end) do
      :ready
    else
      :blocked
    end
  end

  defp status_label(:ready), do: "Ready"
  defp status_label(:failed), do: "Failed"

  defp transition_label(previous_status, status) do
    "#{status_label(previous_status)} -> #{status_label(status)}"
  end

  defp previous_signature_status(%{signature: %{status: status}}), do: status
  defp previous_signature_status(_report), do: :failed

  defp previous_event_statuses(%{events: events}) when is_list(events) do
    Enum.reduce(events, %{}, fn event_result, acc ->
      Map.put(acc, event_result.event, event_result.status)
    end)
  end

  defp previous_event_statuses(_report), do: %{}

  defp configured_events do
    "ISSUE_BOT_WEBHOOK_EVENTS"
    |> System.get_env()
    |> normalize_events()
    |> case do
      [] ->
        Application.get_env(:jido_code, :issue_bot_webhook_events)
        |> normalize_events()

      events ->
        events
    end
    |> case do
      [] -> @default_events
      events -> events
    end
  end

  defp normalize_events(value) when is_binary(value) do
    value
    |> String.split([",", "\n"], trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp normalize_events(values) when is_list(values) do
    values
    |> Enum.map(fn
      value when is_binary(value) -> String.trim(value)
      value when is_atom(value) -> value |> Atom.to_string() |> String.trim()
      _value -> ""
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp normalize_events(_values), do: []

  defp route_for_event("issues.opened"), do: "Issue Bot triage workflow"
  defp route_for_event("issues.edited"), do: "Issue Bot re-triage workflow"
  defp route_for_event("issue_comment.created"), do: "Issue Bot follow-up context workflow"
  defp route_for_event(_event), do: nil

  defp webhook_secret_present? do
    "GITHUB_WEBHOOK_SECRET"
    |> System.get_env()
    |> present_runtime_value()
    |> case do
      nil ->
        Application.get_env(:jido_code, :github_webhook_secret)
        |> present_runtime_value()

      _present ->
        true
    end
  end

  defp present_runtime_value(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      _trimmed -> true
    end
  end

  defp present_runtime_value(_value), do: nil

  defp default_event_name do
    hd(@default_events)
  end

  defp map_get(map, atom_key, string_key) do
    map_get(map, atom_key, string_key, nil)
  end

  defp map_get(map, atom_key, string_key, default) do
    cond do
      Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
      Map.has_key?(map, string_key) -> Map.get(map, string_key)
      true -> default
    end
  end
end
