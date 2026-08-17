defmodule JidoCode.Factory.ModelAuthority do
  @moduledoc "Default fail-closed model authority boundary."

  @behaviour JidoCode.Factory.Ports.ModelAuthority

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Model.BufferedProfile
  alias JidoCode.Factory.Model.Request

  @stages ~w[before_credential_release before_dispatch]a

  @impl true
  def authorize(options, stage, %BufferedProfile{} = profile, %Request{} = request)
      when is_list(options) and stage in @stages do
    case Keyword.get(options, :validator) do
      validator when is_function(validator, 3) ->
        case validator.(stage, profile, request) do
          :ok -> :ok
          {:error, %AdapterError{} = error} -> {:error, error}
          _other -> denied(stage)
        end

      _missing ->
        {:error, AdapterError.new(:unavailable, stage)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, stage)}
  end

  def authorize(_options, stage, _profile, _request) when stage in @stages, do: denied(stage)

  def authorize(_options, _stage, _profile, _request),
    do: {:error, AdapterError.new(:invalid_input, :model_authority)}

  defp denied(stage), do: {:error, AdapterError.new(:unauthorized, stage)}
end
