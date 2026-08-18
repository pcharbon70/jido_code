defmodule JidoCode.Factory.Evaluation.Corpus do
  @moduledoc "Immutable task corpus revision for one evaluation track."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Evaluation.Track
  alias JidoCode.Knowledge

  @enforce_keys [:revision, :track, :digest, :tasks]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @task_keys [
    :task_iri,
    :revision,
    :repository,
    :repository_revision,
    :language,
    :task_class,
    :risk,
    :partition,
    :fresh_private?,
    :oracle_revision
  ]
  @task_classes ~w[bug feature refactor test migration dependency retrieval terminal shadow]a
  @risks ~w[low medium high critical]a
  @partitions ~w[development validation sealed red_team canary shadow]a

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(%{revision: revision, track: track, tasks: tasks})
      when is_list(tasks) and tasks != [] and length(tasks) <= 10_000 do
    with true <- text?(revision, 256),
         {:ok, _track} <- Track.fetch(track),
         {:ok, normalized_tasks} <- tasks(tasks),
         true <- unique?(normalized_tasks, &{&1.task_iri, &1.revision}) do
      digest = digest(%{revision: revision, track: track, tasks: normalized_tasks})

      {:ok,
       %__MODULE__{
         revision: revision,
         track: track,
         digest: digest,
         tasks: normalized_tasks
       }}
    else
      _invalid -> invalid(:evaluation_corpus)
    end
  rescue
    _error -> invalid(:evaluation_corpus)
  end

  def new(_attributes), do: invalid(:evaluation_corpus)

  defp tasks(values) do
    decoded = Enum.map(values, &task/1)

    if Enum.all?(decoded, &match?({:ok, _task}, &1)) do
      normalized = decoded |> Enum.map(&elem(&1, 1)) |> Enum.sort_by(& &1.task_iri)
      {:ok, normalized}
    else
      invalid(:evaluation_tasks)
    end
  end

  defp task(task) when is_map(task) do
    with true <- Enum.sort(Map.keys(task)) == Enum.sort(@task_keys),
         :ok <- resource(task.task_iri),
         true <- text?(task.revision, 256),
         true <- text?(task.repository, 256),
         true <- text?(task.repository_revision, 256),
         true <- text?(task.language, 80),
         true <- task.task_class in @task_classes,
         true <- task.risk in @risks,
         true <- task.partition in @partitions,
         true <- is_boolean(task.fresh_private?),
         true <- text?(task.oracle_revision, 256) do
      {:ok, Map.take(task, @task_keys)}
    else
      _invalid -> invalid(:evaluation_task)
    end
  end

  defp task(_task), do: invalid(:evaluation_task)

  defp unique?(values, key),
    do: values |> Enum.map(key) |> Enum.uniq() |> length() == length(values)

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp resource(value) do
    if Knowledge.validate_resource_identity(value) == :ok,
      do: :ok,
      else: invalid(:evaluation_task_identity)
  end

  defp text?(value, maximum) when is_binary(value),
    do: byte_size(value) in 1..maximum and not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)

  defp text?(_value, _maximum), do: false
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
