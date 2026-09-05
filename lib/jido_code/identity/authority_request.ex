defmodule JidoCode.Identity.AuthorityRequest do
  @moduledoc "Closed, server-constructed request to the trusted human authority builder."

  alias JidoCode.Identity.RoutePolicy

  @enforce_keys [
    :operation,
    :area,
    :action,
    :resource_ref,
    :reauthorization_point,
    :correlation_ref
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}

  @points [
    :before_response_start,
    :before_query_execution,
    :before_field_shaping,
    :before_stream_subscription,
    :before_each_protected_patch,
    :before_command_construction,
    :inside_command_gateway,
    :before_approval_commit,
    :before_export_creation,
    :before_each_export_or_download_retrieval
  ]

  @spec new(map()) :: {:ok, t()} | {:error, :invalid_authority_request}
  def new(attributes) when is_map(attributes) do
    with true <- Enum.sort(Map.keys(attributes)) == Enum.sort(@enforce_keys),
         operation when is_atom(operation) <- attributes[:operation],
         true <- operation in RoutePolicy.operations(),
         area when is_atom(area) <- attributes[:area],
         true <- area in RoutePolicy.areas(),
         action when is_atom(action) <- attributes[:action],
         true <- action in RoutePolicy.actions(),
         resource_ref when resource_ref == :factory or is_binary(resource_ref) <-
           attributes[:resource_ref],
         point when point in @points <- attributes[:reauthorization_point],
         correlation_ref when is_binary(correlation_ref) <- attributes[:correlation_ref],
         true <- byte_size(correlation_ref) in 1..128 do
      {:ok,
       %__MODULE__{
         operation: operation,
         area: area,
         action: action,
         resource_ref: resource_ref,
         reauthorization_point: point,
         correlation_ref: correlation_ref
       }}
    else
      _invalid -> {:error, :invalid_authority_request}
    end
  end

  def new(_attributes), do: {:error, :invalid_authority_request}

  @spec validate(t()) :: {:ok, t()} | {:error, :invalid_authority_request}
  def validate(%__MODULE__{} = request), do: request |> Map.from_struct() |> new()
end
