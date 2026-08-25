defmodule JidoCode.Product.ManagedCodingAttempt do
  @moduledoc "Browser-safe managed coding projection rebuilt from authorized graph facts."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Security.Redactor

  @states ~w[admitted preparing running awaiting_actor assembling_candidate candidate_ready verifying dispositioned delayed unavailable indeterminate cancelled superseded policy_blocked failed]a
  @wait_reasons [nil, :actor, :model, :tool, :capacity, :verifier, :policy]
  @verification ~w[not_started pending passed failed indeterminate unavailable timeout expired]a
  @dispositions [nil, :accepted, :rejected, :indeterminate, :expired, :superseded]
  @internal_keys ~w[attempt_iri repository_iri task_iri profile_iri capability_iri fencing_token sequence actor_iri]a
  @enforce_keys @internal_keys ++
                  ~w[presentation_ref task_label state wait_reason budgets interactions tools checks candidate_ref verification disposition evidence_refs updated_at]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(graph) when is_map(graph) do
    with :ok <- resources(graph),
         fence when is_integer(fence) and fence > 0 <- graph[:fencing_token],
         sequence when is_integer(sequence) and sequence >= 0 <- graph[:sequence],
         state when state in @states <- graph[:state],
         reason when reason in @wait_reasons <- graph[:wait_reason],
         verification when verification in @verification <- graph[:verification],
         disposition when disposition in @dispositions <- graph[:disposition],
         true <- text?(graph[:task_label], 160),
         {:ok, budgets} <- safe_map(graph[:budgets], 32),
         {:ok, interactions} <- safe_summaries(graph[:interactions], 100),
         {:ok, tools} <- safe_summaries(graph[:tools], 100),
         {:ok, checks} <- safe_summaries(graph[:checks], 100),
         {:ok, candidate_ref} <- optional_ref(graph[:candidate_iri]),
         {:ok, evidence_refs} <- refs(graph[:evidence_iris]),
         %DateTime{} = updated_at <- graph[:updated_at],
         presentation_ref <- presentation_ref(graph.attempt_iri) do
      values =
        graph
        |> Map.take(@internal_keys)
        |> Map.merge(%{
          presentation_ref: presentation_ref,
          task_label: graph.task_label,
          state: state,
          wait_reason: reason,
          budgets: budgets,
          interactions: interactions,
          tools: tools,
          checks: checks,
          candidate_ref: candidate_ref,
          verification: verification,
          disposition: disposition,
          evidence_refs: evidence_refs,
          updated_at: DateTime.truncate(updated_at, :microsecond)
        })

      {:ok, struct!(__MODULE__, values)}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_graph), do: invalid()

  @spec view(t()) :: map()
  def view(%__MODULE__{} = attempt) do
    Map.take(attempt, [
      :presentation_ref,
      :task_label,
      :state,
      :wait_reason,
      :budgets,
      :interactions,
      :tools,
      :checks,
      :candidate_ref,
      :verification,
      :disposition,
      :evidence_refs,
      :updated_at
    ])
  end

  @spec presentation_ref(String.t()) :: String.t()
  def presentation_ref(attempt_iri) do
    :crypto.hash(:sha256, "managed-coding-attempt\n" <> attempt_iri)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 32)
  end

  @spec valid_presentation_ref?(term()) :: boolean()
  def valid_presentation_ref?(value),
    do: is_binary(value) and byte_size(value) == 32 and Regex.match?(~r/^[A-Za-z0-9_-]+$/, value)

  defp resources(graph) do
    if Enum.all?(@internal_keys -- [:fencing_token, :sequence], fn field ->
         ResourceIdentity.validate(graph[field]) == :ok
       end),
       do: :ok,
       else: :error
  end

  defp safe_map(value, maximum) when is_map(value) and map_size(value) <= maximum do
    case Redactor.sanitize(value) do
      {:ok, safe, %{redacted_count: 0}} -> {:ok, safe}
      _unsafe -> :error
    end
  end

  defp safe_map(_value, _maximum), do: :error

  defp safe_summaries(values, maximum) when is_list(values) and length(values) <= maximum do
    allowed = [:kind, :label, :status]

    if Enum.all?(values, fn value ->
         is_map(value) and Enum.all?(Map.keys(value), &(&1 in allowed)) and
           text?(value[:label], 160) and is_atom(value[:kind]) and is_atom(value[:status])
       end) do
      normalized =
        Enum.map(values, fn value ->
          %{kind: to_string(value.kind), label: value.label, status: to_string(value.status)}
        end)

      case Redactor.sanitize(normalized) do
        {:ok, safe, %{redacted_count: 0}} -> {:ok, safe}
        _unsafe -> :error
      end
    else
      :error
    end
  end

  defp safe_summaries(_values, _maximum), do: :error

  defp optional_ref(nil), do: {:ok, nil}

  defp optional_ref(iri) do
    with :ok <- ResourceIdentity.validate(iri), do: {:ok, presentation_ref(iri)}
  end

  defp refs(values) when is_list(values) and length(values) <= 128 do
    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
      do: {:ok, values |> Enum.map(&presentation_ref/1) |> Enum.uniq() |> Enum.sort()},
      else: :error
  end

  defp refs(_values), do: :error

  defp text?(value, maximum),
    do:
      is_binary(value) and byte_size(value) in 1..maximum and
        Redactor.reject_sensitive(value) == :ok

  defp invalid, do: {:error, AdapterError.new(:invalid_input, :managed_coding_product_projection)}
end
