defmodule JidoCode.Product.CodingSubmissionProvider do
  @moduledoc "Semantic admission boundary for one exact coding-agent offering."

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Product.WorkflowOutcome

  @callback submit(AuthorityContext.t(), map(), map()) ::
              {:ok, WorkflowOutcome.t()} | {:error, term()}
end
