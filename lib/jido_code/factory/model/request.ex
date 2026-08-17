defmodule JidoCode.Factory.Model.Request do
  @moduledoc """
  Bounded, transient input for one governed model interaction.

  The request identifies the already-recorded invocation and its selected
  access profile. Credentials and provider sessions are deliberately absent;
  later gateway policy supplies credential bytes only at adapter call time.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @derive {Inspect,
           only: [
             :invocation_iri,
             :profile_iri,
             :context_manifest_iri,
             :provider,
             :model,
             :deadline
           ]}
  @enforce_keys [
    :invocation_iri,
    :profile_iri,
    :context_manifest_iri,
    :provider,
    :model,
    :messages,
    :options,
    :deadline
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @max_messages_bytes 262_144
  @max_options_bytes 32_768
  @provider ~r/^[a-z][a-z0-9_-]{0,63}$/

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    resources = ~w[invocation_iri profile_iri context_manifest_iri]a

    with true <-
           Enum.all?(resources, &(Knowledge.validate_resource_identity(attributes[&1]) == :ok)),
         provider when is_binary(provider) <- attributes[:provider],
         true <- Regex.match?(@provider, provider),
         model when is_binary(model) <- attributes[:model],
         true <- bounded_text?(model, 192),
         messages when is_binary(messages) or is_list(messages) <- attributes[:messages],
         true <- bounded?(messages, @max_messages_bytes),
         options when is_list(options) <- attributes[:options],
         true <- Keyword.keyword?(options),
         true <- bounded?(options, @max_options_bytes),
         %DateTime{} = deadline <- attributes[:deadline] do
      {:ok,
       %__MODULE__{
         invocation_iri: attributes.invocation_iri,
         profile_iri: attributes.profile_iri,
         context_manifest_iri: attributes.context_manifest_iri,
         provider: provider,
         model: model,
         messages: messages,
         options: options,
         deadline: DateTime.truncate(deadline, :microsecond)
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  @spec model_spec(t()) :: String.t()
  def model_spec(%__MODULE__{} = request), do: request.provider <> ":" <> request.model

  defp bounded?(value, maximum) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> byte_size()
    |> Kernel.<=(maximum)
  end

  defp bounded_text?(value, maximum) do
    byte_size(value) in 1..maximum and not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)
  end

  defp invalid, do: {:error, AdapterError.new(:invalid_input, :model_request)}
end
