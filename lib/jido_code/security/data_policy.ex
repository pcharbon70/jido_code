defmodule JidoCode.Security.DataPolicy do
  @moduledoc """
  Closed data-classification policy shared by product and operational outputs.
  """

  @classifications [
    :public,
    :internal,
    :confidential,
    :secret_reference,
    :secret_value,
    :source_body,
    :prompt,
    :tool_output,
    :personal,
    :audit
  ]

  @rules %{
    public: %{graphs: [:ontology], outputs: [:ui, :docs, :telemetry]},
    internal: %{graphs: [:factory_catalog, :repository_control], outputs: [:ui, :audit]},
    confidential: %{
      graphs: [:observation_batch, :source_revision],
      outputs: [:authorized_ui, :audit]
    },
    secret_reference: %{graphs: [:factory_policy], outputs: [:authorized_ui, :audit]},
    secret_value: %{graphs: [], outputs: []},
    source_body: %{graphs: [:source_revision], outputs: [:bounded_artifact]},
    prompt: %{graphs: [], outputs: []},
    tool_output: %{graphs: [], outputs: [:bounded_artifact]},
    personal: %{graphs: [:security_audit], outputs: [:authorized_audit]},
    audit: %{graphs: [:security_audit], outputs: [:authorized_audit]}
  }

  @sensitive_keys ~w[
    access_token api_key authorization bearer client_secret cookie credential
    password private_key prompt secret session source_body stdout stderr token
  ]

  @spec classifications() :: [atom()]
  def classifications, do: @classifications

  @spec rule(atom()) :: {:ok, map()} | :error
  def rule(classification) when classification in @classifications,
    do: {:ok, Map.fetch!(@rules, classification)}

  def rule(_classification), do: :error

  @spec classify_key(String.t() | atom()) :: atom()
  def classify_key(key) do
    normalized = key |> to_string() |> String.downcase()

    if Enum.any?(@sensitive_keys, &String.contains?(normalized, &1)),
      do: :secret_value,
      else: :internal
  end

  @spec durable_allowed?(atom(), atom()) :: boolean()
  def durable_allowed?(classification, graph_family) do
    case rule(classification) do
      {:ok, %{graphs: graphs}} -> graph_family in graphs
      :error -> false
    end
  end
end
