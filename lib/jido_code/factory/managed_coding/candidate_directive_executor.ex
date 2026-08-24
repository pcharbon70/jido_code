defmodule JidoCode.Factory.ManagedCoding.CandidateDirectiveExecutor do
  @moduledoc "Captures one immutable local candidate without verification or publication authority."

  @behaviour JidoCode.Factory.Ports.ManagedCodingDirective

  alias JidoCode.Factory.AdapterError

  @digest ~r/^[a-f0-9]{64}$/

  @impl true
  def execute(state, %{kind: :candidate} = envelope, _options) when is_map(state) do
    with capture when is_function(capture, 2) <- state[:capture],
         {:ok, result} when is_map(result) <- capture.(envelope, envelope.payload),
         digest when is_binary(digest) <- result[:candidate_digest],
         true <- Regex.match?(@digest, digest),
         false <- result[:verified?] == true,
         false <- result[:published?] == true do
      {:ok,
       %{
         outcome: :completed,
         candidate_digest: digest,
         verification_status: :not_started,
         publication_authority: false
       }}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :managed_coding_candidate_directive)}
  end

  def execute(_state, _envelope, _options), do: invalid()

  defp invalid,
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_candidate_directive)}
end
