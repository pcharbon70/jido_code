defmodule JidoCode.Product.GraphCodingSubmissionProvider do
  @moduledoc "Submits normalized intent through the configured semantic-admission adapter."

  @behaviour JidoCode.Product.CodingSubmissionProvider

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Product.WorkflowOutcome

  @impl true
  def submit(%AuthorityContext{} = authority, identity, request) when is_map(identity) do
    admit = Application.get_env(:jido_code, :coding_submission_admitter)

    with admit when is_function(admit, 3) <- admit,
         {:ok, %WorkflowOutcome{} = outcome} <- admit.(authority, identity, request) do
      {:ok, outcome}
    else
      _unavailable -> {:error, :unavailable}
    end
  rescue
    _error -> {:error, :unavailable}
  end

  def submit(_authority, _identity, _request), do: {:error, :unauthorized}
end
