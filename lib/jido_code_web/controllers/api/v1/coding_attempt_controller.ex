defmodule JidoCodeWeb.Api.V1.CodingAttemptController do
  use JidoCodeWeb, :controller

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Product.CodingSubmissionGateway
  alias JidoCode.Product.GraphManagedCodingAttemptProvider
  alias JidoCode.Product.ManagedCodingAttempt
  alias JidoCode.Product.ManagedCodingControlGateway
  alias JidoCodeWeb.Api.V1.ProductResponse

  @controls ~w[steer answer cancel handoff recovery]

  def create(conn, params) do
    gateway =
      Application.get_env(:jido_code, :coding_submission_gateway, CodingSubmissionGateway)

    case invoke_submission(gateway, conn.assigns.authority, conn.assigns.product_identity, params) do
      {:ok, outcome} -> ProductResponse.workflow(conn, outcome)
      {:error, error} -> ProductResponse.error(conn, error)
    end
  end

  def show(conn, %{"attempt_ref" => reference}), do: render_attempt(conn, reference)
  def refresh(conn, %{"attempt_ref" => reference}), do: render_attempt(conn, reference)

  def control(conn, %{"attempt_ref" => reference, "control" => action} = params)
      when action in @controls do
    provider =
      Application.get_env(
        :jido_code,
        :managed_coding_attempt_provider,
        GraphManagedCodingAttemptProvider
      )

    gateway =
      Application.get_env(
        :jido_code,
        :managed_coding_control_gateway,
        ManagedCodingControlGateway
      )

    with {:ok, %ManagedCodingAttempt{} = attempt} <-
           provider.load(conn.assigns.authority, conn.assigns.product_identity, reference),
         {:ok, operation} <- control_action(action),
         control_params <- Map.drop(params, ["attempt_ref", "control"]),
         {:ok, outcome} <-
           gateway.submit(
             conn.assigns.authority,
             conn.assigns.product_identity,
             attempt,
             operation,
             control_params,
             []
           ) do
      ProductResponse.ok(conn, %{
        control: action,
        state: outcome.state,
        sequence: outcome.sequence
      })
    else
      {:error, %AdapterError{} = error} -> ProductResponse.error(conn, error)
      _invalid -> ProductResponse.error(conn, AdapterError.new(:unavailable, :coding_control_api))
    end
  end

  def control(conn, _params),
    do: ProductResponse.error(conn, AdapterError.new(:invalid_input, :coding_control_api))

  defp render_attempt(conn, reference) do
    provider =
      Application.get_env(
        :jido_code,
        :managed_coding_attempt_provider,
        GraphManagedCodingAttemptProvider
      )

    case provider.load(conn.assigns.authority, conn.assigns.product_identity, reference) do
      {:ok, %ManagedCodingAttempt{} = attempt} ->
        ProductResponse.ok(conn, %{attempt: ManagedCodingAttempt.view(attempt)})

      {:error, :unauthorized} ->
        ProductResponse.error(conn, AdapterError.new(:unauthorized, :coding_attempt_api))

      _unavailable ->
        ProductResponse.error(conn, AdapterError.new(:unavailable, :coding_attempt_api))
    end
  end

  defp invoke_submission(gateway, authority, identity, params) when is_atom(gateway),
    do: gateway.submit(authority, identity, params)

  defp invoke_submission(gateway, authority, identity, params) when is_function(gateway, 3),
    do: gateway.(authority, identity, params)

  defp control_action("steer"), do: {:ok, :steer}
  defp control_action("answer"), do: {:ok, :answer}
  defp control_action("cancel"), do: {:ok, :cancel}
  defp control_action("handoff"), do: {:ok, :handoff}
  defp control_action("recovery"), do: {:ok, :recovery}
end
