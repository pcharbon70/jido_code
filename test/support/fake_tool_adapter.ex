defmodule JidoCode.TestSupport.FakeToolAdapter do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.Tool

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.Result

  @impl true
  def execute(_adapter, request, options) do
    case Keyword.get(options, :scenario, :success) do
      :success ->
        Result.new(
          %{
            status: :completed,
            exit_status: 0,
            stdout: "applied",
            stderr: "",
            external_output_iris: [],
            usage: %{cpu_ms: 2, output_bytes: 7},
            artifact_iris: [],
            redaction: :none
          },
          request.output_bytes
        )

      :secret ->
        Result.new(
          %{
            status: :completed,
            exit_status: 0,
            stdout: "token=ghp_abcdefghijklmnopqrstuvwxyz",
            stderr: "",
            external_output_iris: [],
            usage: %{},
            artifact_iris: [],
            redaction: :none
          },
          request.output_bytes
        )

      :semantic_command ->
        {:ok, %{command_type: "AdoptKnowledge"}}

      :unavailable ->
        {:error, AdapterError.new(:unavailable, :tool_execute)}
    end
  end
end
