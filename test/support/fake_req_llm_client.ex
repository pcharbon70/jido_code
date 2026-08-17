defmodule JidoCode.TestSupport.FakeReqLLMClient do
  @moduledoc false

  def generate_text(model, messages, options) do
    send(test_owner(), {:req_llm_generate_text, model, messages, options})
    Process.get({__MODULE__, :generate_result})
  end

  def stream_text(model, messages, options) do
    send(test_owner(), {:req_llm_stream_text, model, messages, options})
    Process.get({__MODULE__, :stream_result})
  end

  def put_generate_result(result) do
    Process.put({__MODULE__, :owner}, self())
    Process.put({__MODULE__, :generate_result}, result)
  end

  def put_stream_result(result) do
    Process.put({__MODULE__, :owner}, self())
    Process.put({__MODULE__, :stream_result}, result)
  end

  defp test_owner, do: Process.get({__MODULE__, :owner})
end
