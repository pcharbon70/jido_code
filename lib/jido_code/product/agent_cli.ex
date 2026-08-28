defmodule JidoCode.Product.AgentCLI do
  @moduledoc """
  Authenticated, machine-readable coding-agent commands shared by the Mix task.

  The caller supplies an already protected credential value and a decoded JSON
  object. This module reuses the product authentication, authority construction,
  gateways, and projections used by the browser and JSON API.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Product
  alias JidoCode.Product.AgentCatalogGateway
  alias JidoCode.Product.AgentOffering
  alias JidoCode.Product.CodingSubmissionGateway
  alias JidoCode.Product.GraphManagedCodingAttemptProvider
  alias JidoCode.Product.ManagedCodingAttempt
  alias JidoCode.Product.ManagedCodingControlGateway
  alias JidoCode.Product.WorkflowOutcome
  alias JidoCode.Security.Redactor
  alias JidoCodeWeb.ProductAuth

  @commands ~w[catalog submit show steer answer cancel handoff recovery]
  @catalog_fields ~w[repository_ref snapshot_ref task_class language_class capability_class rollout_stage]
  @submission_fields ~w[intent repository_ref snapshot_ref task_class acceptance_requirements offering_ref idempotency_key foreground_consent billing_acknowledged]
  @control_fields %{
    "steer" => ~w[attempt_ref message idempotency_key],
    "answer" => ~w[attempt_ref message idempotency_key],
    "cancel" => ~w[attempt_ref confirmed idempotency_key],
    "handoff" => ~w[attempt_ref idempotency_key],
    "recovery" => ~w[attempt_ref confirmed idempotency_key]
  }

  @spec commands() :: [String.t()]
  def commands, do: @commands

  @spec execute(String.t(), map(), String.t(), keyword()) ::
          {:ok, map()} | {:error, map()}
  def execute(command, request, credential, options \\ [])

  def execute(command, request, credential, options)
      when command in @commands and is_map(request) and is_binary(credential) and
             is_list(options) do
    with :ok <- ProductAuth.authenticate(credential),
         :ok <- validate_request(command, request),
         identity <- ProductAuth.product_identity(),
         {:ok, authority} <- Product.authority(identity) do
      dispatch(command, request, authority, identity, options)
    else
      :error -> error(:unauthorized)
      {:error, %AdapterError{} = adapter_error} -> error(adapter_error.kind, adapter_error.retry)
      _invalid -> error(:rejected)
    end
  rescue
    _error -> error(:unavailable, :retry)
  end

  def execute(_command, _request, _credential, _options), do: error(:rejected)

  defp dispatch("catalog", request, authority, identity, options) do
    gateway =
      Keyword.get(
        options,
        :catalog_gateway,
        Application.get_env(:jido_code, :agent_catalog_gateway, AgentCatalogGateway)
      )

    case invoke_catalog(gateway, authority, identity, request) do
      {:ok, offerings} ->
        {:ok,
         %{
           outcome: "admitted",
           offerings: Enum.map(offerings, &AgentOffering.safe_map/1)
         }}

      {:error, %AdapterError{} = adapter_error} ->
        error(adapter_error.kind, adapter_error.retry)

      _unavailable ->
        error(:unavailable, :retry)
    end
  end

  defp dispatch("submit", request, authority, identity, options) do
    gateway =
      Keyword.get(
        options,
        :submission_gateway,
        Application.get_env(:jido_code, :coding_submission_gateway, CodingSubmissionGateway)
      )

    case invoke_submission(gateway, authority, identity, request) do
      {:ok, %WorkflowOutcome{} = outcome} -> {:ok, WorkflowOutcome.safe_map(outcome)}
      {:error, %AdapterError{} = adapter_error} -> error(adapter_error.kind, adapter_error.retry)
      _unavailable -> error(:unavailable, :retry)
    end
  end

  defp dispatch("show", %{"attempt_ref" => reference}, authority, identity, options) do
    provider = attempt_provider(options)

    case provider.load(authority, identity, reference) do
      {:ok, %ManagedCodingAttempt{} = attempt} ->
        {:ok, %{outcome: "admitted", attempt: ManagedCodingAttempt.view(attempt)}}

      {:error, :unauthorized} ->
        error(:unauthorized)

      _unavailable ->
        error(:unavailable, :retry)
    end
  end

  defp dispatch(command, %{"attempt_ref" => reference} = request, authority, identity, options)
       when command in ~w[steer answer cancel handoff recovery] do
    provider = attempt_provider(options)
    gateway = control_gateway(options)

    with {:ok, %ManagedCodingAttempt{} = attempt} <- provider.load(authority, identity, reference),
         {:ok, outcome} <-
           gateway.submit(
             authority,
             identity,
             attempt,
             String.to_existing_atom(command),
             Map.delete(request, "attempt_ref"),
             []
           ) do
      {:ok,
       %{
         outcome: "admitted",
         control: command,
         state: outcome.state,
         sequence: outcome.sequence
       }}
    else
      {:error, %AdapterError{} = adapter_error} -> error(adapter_error.kind, adapter_error.retry)
      {:error, :unauthorized} -> error(:unauthorized)
      _unavailable -> error(:unavailable, :retry)
    end
  end

  defp validate_request(command, request) do
    allowed = allowed_fields(command)

    with true <- map_size(request) <= length(allowed),
         true <- Enum.all?(Map.keys(request), &(is_binary(&1) and &1 in allowed)),
         true <- Enum.all?(required_fields(command), &Map.has_key?(request, &1)),
         :ok <- Redactor.reject_sensitive(request) do
      :ok
    else
      _invalid -> {:error, AdapterError.new(:invalid_input, :coding_agent_cli)}
    end
  end

  defp allowed_fields("catalog"), do: @catalog_fields
  defp allowed_fields("submit"), do: @submission_fields
  defp allowed_fields("show"), do: ["attempt_ref"]
  defp allowed_fields(command), do: Map.fetch!(@control_fields, command)

  defp required_fields("show"), do: ["attempt_ref"]

  defp required_fields(command) when command in ~w[steer answer cancel handoff recovery],
    do: Map.fetch!(@control_fields, command)

  defp required_fields(_command), do: []

  defp attempt_provider(options) do
    Keyword.get(
      options,
      :attempt_provider,
      Application.get_env(
        :jido_code,
        :managed_coding_attempt_provider,
        GraphManagedCodingAttemptProvider
      )
    )
  end

  defp control_gateway(options) do
    Keyword.get(
      options,
      :control_gateway,
      Application.get_env(
        :jido_code,
        :managed_coding_control_gateway,
        ManagedCodingControlGateway
      )
    )
  end

  defp invoke_catalog(gateway, authority, identity, request) when is_atom(gateway),
    do: gateway.list(authority, identity, request)

  defp invoke_catalog(gateway, authority, identity, request) when is_function(gateway, 3),
    do: gateway.(authority, identity, request)

  defp invoke_submission(gateway, authority, identity, request) when is_atom(gateway),
    do: gateway.submit(authority, identity, request)

  defp invoke_submission(gateway, authority, identity, request) when is_function(gateway, 3),
    do: gateway.(authority, identity, request)

  defp error(code, retry \\ :never)

  defp error(:invalid_input, retry), do: error(:rejected, retry)
  defp error(:corrupt, retry), do: error(:rejected, retry)
  defp error(:timeout, _retry), do: error(:unavailable, :retry)

  defp error(code, retry) do
    {:error, %{outcome: to_string(code), retry: to_string(retry)}}
  end
end
