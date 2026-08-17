defmodule JidoCode.Factory.Credential.Policy do
  @moduledoc "Closed graph-derived authority for one brokered credential release."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.CredentialReference
  alias JidoCode.Knowledge

  @derive {Inspect,
           only: [
             :reference,
             :credential_class,
             :provider,
             :operation,
             :audience,
             :scopes,
             :expires_at,
             :single_use,
             :managed_eligible
           ]}
  @enforce_keys [
    :reference,
    :credential_class,
    :actor_iri,
    :delegated_agent_iri,
    :delegation_iri,
    :repository_iri,
    :provider,
    :operation,
    :audience,
    :scopes,
    :expires_at,
    :single_use,
    :attempt_iri,
    :lease_iri,
    :fencing_token,
    :trusted_connector_identity,
    :enforcement,
    :profile_revision,
    :credential_revision,
    :revocation_generation,
    :invocation_iri,
    :explicit_local_consent,
    :managed_eligible
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @classes ~w[provider_token oauth_access delegated_cli local_cli_reference]a
  @enforcement ~w[provider_native token_exchange attaching_proxy broker_helper existing_cli_session]a

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with %CredentialReference{} <- attributes[:reference],
         class when class in @classes <- attributes[:credential_class],
         :ok <- resource(attributes[:actor_iri]),
         :ok <- optional_resource(attributes[:delegated_agent_iri]),
         :ok <- optional_resource(attributes[:delegation_iri]),
         :ok <- resource(attributes[:repository_iri]),
         :ok <- resource(attributes[:attempt_iri]),
         :ok <- resource(attributes[:lease_iri]),
         :ok <- resource(attributes[:invocation_iri]),
         :ok <- text(attributes[:provider], 64),
         :ok <- text(attributes[:operation], 128),
         :ok <- text(attributes[:audience], 256),
         :ok <- strings(attributes[:scopes], 100, 128),
         %DateTime{} <- attributes[:expires_at],
         true <- is_boolean(attributes[:single_use]),
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         :ok <- connector_identity(attributes[:trusted_connector_identity]),
         enforcement when enforcement in @enforcement <- attributes[:enforcement],
         true <- revisions?(attributes),
         true <- is_boolean(attributes[:explicit_local_consent]),
         true <- is_boolean(attributes[:managed_eligible]),
         :ok <- class_boundary(attributes) do
      values =
        attributes
        |> Map.take(@enforce_keys)
        |> Map.update!(:scopes, &Enum.sort/1)

      {:ok, struct!(__MODULE__, values)}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  defp class_boundary(%{
         credential_class: :local_cli_reference,
         enforcement: :existing_cli_session,
         explicit_local_consent: true,
         managed_eligible: false,
         single_use: false
       }),
       do: :ok

  defp class_boundary(%{credential_class: :local_cli_reference}), do: :error

  defp class_boundary(%{
         credential_class: :delegated_cli,
         enforcement: :broker_helper,
         explicit_local_consent: false,
         managed_eligible: true
       }),
       do: :ok

  defp class_boundary(%{credential_class: :delegated_cli}), do: :error

  defp class_boundary(%{enforcement: enforcement, explicit_local_consent: false})
       when enforcement in [:provider_native, :token_exchange, :attaching_proxy],
       do: :ok

  defp class_boundary(_attributes), do: :error

  defp revisions?(attributes) do
    Enum.all?(~w[profile_revision credential_revision revocation_generation]a, fn key ->
      value = attributes[key]
      is_integer(value) and value >= 0
    end)
  end

  defp connector_identity(value) when is_binary(value) do
    if Regex.match?(~r/^[A-Za-z0-9_.:-]{1,192}@sha256:[a-f0-9]{64}$/, value),
      do: :ok,
      else: :error
  end

  defp connector_identity(_value), do: :error
  defp resource(value), do: Knowledge.validate_resource_identity(value)
  defp optional_resource(nil), do: :ok
  defp optional_resource(value), do: resource(value)

  defp strings(values, maximum_count, maximum_bytes)
       when is_list(values) and length(values) in 1..maximum_count//1 do
    if values == Enum.uniq(values) and Enum.all?(values, &(text(&1, maximum_bytes) == :ok)),
      do: :ok,
      else: :error
  end

  defp strings(_values, _count, _bytes), do: :error

  defp text(value, maximum) when is_binary(value) do
    if byte_size(value) in 1..maximum and not Regex.match?(~r/[\x00-\x1F\x7F]/u, value),
      do: :ok,
      else: :error
  end

  defp text(_value, _maximum), do: :error
  defp invalid, do: {:error, AdapterError.new(:invalid_input, :credential_policy)}
end
