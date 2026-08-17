defmodule JidoCode.Runtime.JidoHarness.Readiness do
  @moduledoc "Prompt-free readiness discovery and explicit-consent live smoke gate."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Runtime.JidoHarness.Adoption
  alias JidoCode.Runtime.JidoHarness.JidoHarnessReadinessProbe

  @spec discover(atom(), keyword()) :: {:ok, map()} | {:error, AdapterError.t()}
  def discover(profile_name, options \\ [])

  def discover(profile_name, options) when is_atom(profile_name) and is_list(options) do
    with {:ok, profile} <- Adoption.profile(profile_name),
         {:ok, status} <- invoke(:discover, profile, options),
         {:ok, receipt} <- discovery_receipt(profile, status) do
      {:ok, receipt}
    end
  end

  def discover(_profile_name, _options), do: invalid(:jido_harness_readiness)

  @spec live_smoke(atom(), map(), keyword()) :: {:ok, map()} | {:error, AdapterError.t()}
  def live_smoke(profile_name, consent, options \\ [])

  def live_smoke(profile_name, consent, options)
      when is_atom(profile_name) and is_map(consent) and is_list(options) do
    with {:ok, profile} <- Adoption.profile(profile_name),
         :ok <- validate_consent(profile_name, consent, options),
         {:ok, status} <- invoke(:live_smoke, profile, options),
         {:ok, receipt} <- live_receipt(profile, status) do
      {:ok, receipt}
    end
  end

  def live_smoke(_profile_name, _consent, _options),
    do: invalid(:jido_harness_live_smoke)

  defp discovery_receipt(profile, status) when is_map(status) do
    with installed when is_boolean(installed) <- Map.get(status, :installed),
         compatible when is_boolean(compatible) <- Map.get(status, :compatible),
         authenticated when authenticated in [true, false, :unknown] <-
           Map.get(status, :authenticated),
         :ok <- optional_version(Map.get(status, :version)) do
      {:ok,
       %{
         profile: profile.name,
         provider: profile.provider,
         probe: :non_billable_discovery,
         prompt_sent: false,
         installed: installed,
         compatible: compatible,
         ready: installed and compatible and authenticated != false,
         version: Map.get(status, :version),
         authentication: %{
           state: authenticated,
           evidence: authentication_evidence(authenticated),
           actor_identity: :not_claimed
         }
       }}
    else
      _invalid -> invalid(:jido_harness_readiness_receipt)
    end
  end

  defp discovery_receipt(_profile, _status),
    do: invalid(:jido_harness_readiness_receipt)

  defp live_receipt(profile, status) when is_map(status) do
    with result when result in [:passed, :failed] <- Map.get(status, :result),
         authenticated when authenticated in [true, false, :unknown] <-
           Map.get(status, :authenticated, :unknown) do
      {:ok,
       %{
         profile: profile.name,
         provider: profile.provider,
         probe: :consented_live_smoke,
         result: result,
         authentication: %{
           state: authenticated,
           evidence: authentication_evidence(authenticated),
           actor_identity: :not_claimed
         }
       }}
    else
      _invalid -> invalid(:jido_harness_live_smoke_receipt)
    end
  end

  defp live_receipt(_profile, _status),
    do: invalid(:jido_harness_live_smoke_receipt)

  defp validate_consent(profile_name, consent, options) do
    at = Keyword.get(options, :at, DateTime.utc_now())

    if consent[:granted] == true and consent[:billing_acknowledged] == true and
         consent[:profile] == profile_name and is_binary(consent[:actor_iri]) and
         String.starts_with?(consent.actor_iri, "https://jido.run/id/") and
         match?(%DateTime{}, consent[:expires_at]) and
         DateTime.compare(consent.expires_at, at) == :gt do
      :ok
    else
      invalid(:jido_harness_live_consent)
    end
  end

  defp invoke(operation, profile, options) do
    probe = Keyword.get(options, :probe, JidoHarnessReadinessProbe)
    probe_options = Keyword.get(options, :probe_options, [])

    if is_atom(probe) and Code.ensure_loaded?(probe) and
         function_exported?(probe, operation, 2) do
      case apply(probe, operation, [profile, probe_options]) do
        {:ok, status} when is_map(status) -> {:ok, status}
        {:error, %AdapterError{} = error} -> {:error, error}
        {:error, _reason} -> unavailable(operation)
        _invalid -> invalid(operation)
      end
    else
      unavailable(operation)
    end
  rescue
    _error -> unavailable(operation)
  end

  defp optional_version(nil), do: :ok
  defp optional_version(value) when is_binary(value) and byte_size(value) in 1..128, do: :ok
  defp optional_version(_value), do: :error
  defp authentication_evidence(true), do: :credential_signal_observed
  defp authentication_evidence(false), do: :credential_absence_observed
  defp authentication_evidence(:unknown), do: :not_proven_without_live_request
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
end
