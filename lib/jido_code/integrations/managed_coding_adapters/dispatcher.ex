defmodule JidoCode.Integrations.ManagedCodingAdapters.Dispatcher do
  @moduledoc false

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.MutationRequest
  alias JidoCode.Factory.ManagedCoding.ReadRequest
  alias JidoCode.Factory.Tool.Request
  alias JidoCode.Factory.Tool.Result
  alias JidoCode.Integrations.ManagedCodingCandidateTools
  alias JidoCode.Integrations.ManagedCodingMutationTools
  alias JidoCode.Integrations.ManagedCodingReadTools

  @spec execute(String.t(), map(), Request.t(), keyword()) ::
          {:ok, Result.t()} | {:error, AdapterError.t()}
  def execute(name, state, %Request{} = request, options) when is_map(state) do
    with :ok <- exact_request?(name, state, request),
         {:ok, value} <- invoke(name, state, request.arguments, options),
         {:ok, result} <- result(name, value, request.output_bytes) do
      {:ok, result}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :managed_coding_adapter)}
  end

  def execute(_name, _state, _request, _options),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_adapter)}

  defp invoke(
         "inspect_symbol",
         %{read_request: %ReadRequest{} = request, analysis_revision_number: expected},
         arguments,
         _options
       ) do
    with ^expected <- arguments[:expected_revision] do
      arguments =
        arguments
        |> Map.put(:expected_analysis_revision, request.analysis_revision)
        |> Map.delete(:expected_revision)

      ManagedCodingReadTools.inspect_symbol(request, arguments)
    else
      _stale -> {:error, AdapterError.new(:conflict, :managed_coding_analysis_revision)}
    end
  end

  defp invoke("search_source", %{read_request: %ReadRequest{} = request}, arguments, _options),
    do: ManagedCodingReadTools.search_source(request, arguments)

  defp invoke("read_file", %{read_request: %ReadRequest{} = request}, arguments, _options),
    do: ManagedCodingReadTools.read_file(request, arguments)

  defp invoke(
         "apply_edit",
         %{mutation_request: %MutationRequest{} = request} = state,
         arguments,
         options
       ) do
    merged = Keyword.merge(Map.get(state, :effect_options, []), options)
    ManagedCodingMutationTools.apply_edit(request, arguments, merged)
  end

  defp invoke(
         "create_file",
         %{mutation_request: %MutationRequest{} = request} = state,
         arguments,
         options
       ) do
    merged = Keyword.merge(Map.get(state, :effect_options, []), options)
    ManagedCodingMutationTools.create_file(request, arguments, merged)
  end

  defp invoke(
         "delete_file",
         %{mutation_request: %MutationRequest{} = request} = state,
         arguments,
         options
       ) do
    merged = Keyword.merge(Map.get(state, :effect_options, []), options)
    ManagedCodingMutationTools.delete_file(request, arguments, merged)
  end

  defp invoke(
         "run_registered_check",
         %{mutation_request: %MutationRequest{} = request} = state,
         arguments,
         options
       ) do
    ManagedCodingCandidateTools.run_registered_check(
      request,
      arguments,
      Keyword.merge(Map.get(state, :effect_options, []), options)
    )
  end

  defp invoke(
         "show_candidate_diff",
         %{mutation_request: %MutationRequest{} = request} = state,
         arguments,
         options
       ) do
    ManagedCodingCandidateTools.show_candidate_diff(
      request,
      arguments,
      Keyword.merge(Map.get(state, :effect_options, []), options)
    )
  end

  defp invoke(_name, _state, _arguments, _options),
    do: {:error, AdapterError.new(:unavailable, :managed_coding_adapter_state)}

  defp result(name, value, maximum) do
    status = status(value)
    stdout = value |> json_safe() |> Jason.encode!()

    Result.new(
      %{
        status: status,
        exit_status: exit_status(value),
        stdout: stdout,
        stderr: "",
        external_output_iris: [],
        usage: %{tool: name, output_bytes: byte_size(stdout)},
        artifact_iris: [],
        redaction: if(Map.get(value, :redacted?, false), do: :applied, else: :none)
      },
      maximum
    )
  end

  defp status(%{status: :timeout}), do: :timed_out
  defp status(%{status: :cancelled}), do: :cancelled

  defp status(%{status: value}) when value in [:failure, :infrastructure_failure, :unavailable],
    do: :failed

  defp status(_value), do: :completed

  defp exit_status(%{exit_code: code}) when is_integer(code) and code in 0..255, do: code
  defp exit_status(_value), do: nil

  defp json_safe(value) when is_map(value),
    do: Map.new(value, fn {key, item} -> {key, json_safe(item)} end)

  defp json_safe(value) when is_list(value), do: Enum.map(value, &json_safe/1)
  defp json_safe(value) when is_tuple(value), do: value |> Tuple.to_list() |> json_safe()

  defp json_safe(value) when is_binary(value),
    do:
      if(String.valid?(value),
        do: value,
        else: %{"encoding" => "base64", "data" => Base.encode64(value)}
      )

  defp json_safe(value) when is_atom(value), do: Atom.to_string(value)
  defp json_safe(value), do: value

  defp exact_request?(name, state, request) do
    expected = Map.get(state, :tool_iris, %{})[name]

    if expected == request.tool_iri,
      do: :ok,
      else: {:error, AdapterError.new(:unauthorized, :managed_coding_adapter_binding)}
  end
end
