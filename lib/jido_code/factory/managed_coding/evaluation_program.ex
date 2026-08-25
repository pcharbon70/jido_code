defmodule JidoCode.Factory.ManagedCoding.EvaluationProgram do
  @moduledoc "Private, reproducible qualification corpus and predeclared release analysis."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Evaluation.Metrics
  alias JidoCode.Factory.ManagedCoding.Identity

  @task_classes ~w[inspect defect_repair focused_feature test_repair refactor documentation abstention clarification policy_refusal unsupported_task]a
  @conditions ~w[ambiguous malicious_instruction flaky_check failure cancellation recovery_point]a
  @binary_metrics ~w[task_correct regression_free unsafe_action_free authority_compliant supported_claim abstention_quality recovery_success]a
  @continuous_metrics ~w[latency_ms resource_units tokens cost_microunits]a
  @digest ~r/^[a-f0-9]{64}$/
  @enforce_keys ~w[revision profile_digest corpus_revision tasks trials_per_task thresholds baselines minimum_sample_size maximum_variance regression_tolerance analysis_revision digest]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with revision when is_binary(revision) and byte_size(revision) in 1..128 <-
           attributes[:revision],
         true <- valid_digest?(attributes[:profile_digest]),
         corpus_revision when is_binary(corpus_revision) and byte_size(corpus_revision) in 1..128 <-
           attributes[:corpus_revision],
         {:ok, tasks} <- tasks(attributes[:tasks]),
         trials when is_integer(trials) and trials in 2..50 <- attributes[:trials_per_task],
         :ok <- thresholds(attributes[:thresholds]),
         :ok <- baselines(attributes[:baselines]),
         sample when is_integer(sample) and sample > 0 <- attributes[:minimum_sample_size],
         variance when is_number(variance) and variance >= 0 <- attributes[:maximum_variance],
         tolerance when is_number(tolerance) and tolerance >= 0 <-
           attributes[:regression_tolerance],
         analysis when is_binary(analysis) and byte_size(analysis) in 1..128 <-
           attributes[:analysis_revision] do
      material = %{
        revision: revision,
        profile_digest: attributes.profile_digest,
        corpus_revision: corpus_revision,
        tasks: tasks,
        trials_per_task: trials,
        thresholds: attributes.thresholds,
        baselines: attributes.baselines,
        minimum_sample_size: sample,
        maximum_variance: variance,
        regression_tolerance: tolerance,
        analysis_revision: analysis
      }

      {:ok, struct!(__MODULE__, Map.put(material, :digest, digest(material)))}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  @spec plan(t()) :: [map()]
  def plan(%__MODULE__{} = program) do
    for task <- program.tasks, run <- 1..program.trials_per_task do
      %{
        trial_id: digest({program.digest, task.task_iri, task.revision, run}),
        profile_digest: program.profile_digest,
        corpus_digest: program.digest,
        task_iri: task.task_iri,
        task_revision: task.revision,
        base_revision: task.base_revision,
        seed: task.seed + run,
        run_index: run,
        fresh_workspace: true,
        independent_verification: true,
        artifact_capture: :complete,
        review: if(task.human_judgment, do: :blinded, else: :oracle),
        prompt: Map.take(task, [:task_iri, :task_class, :language, :request_digest])
      }
    end
  end

  @spec score(t(), [map()]) :: {:ok, map()} | {:error, AdapterError.t()}
  def score(%__MODULE__{} = program, trials) when is_list(trials) and trials != [] do
    with true <- length(trials) == length(plan(program)),
         true <- unique?(trials, :trial_id),
         true <- Enum.all?(trials, &valid_trial?(&1, program)),
         true <- failure_reviews_complete?(trials) do
      binary = Map.new(@binary_metrics, &{&1, binary_metric(trials, &1)})
      continuous = Map.new(@continuous_metrics, &{&1, continuous_metric(trials, &1)})
      blocking = blocking_failures(program, binary, continuous)

      {:ok,
       %{
         profile_digest: program.profile_digest,
         corpus_digest: program.digest,
         sample_size: length(trials),
         binary: binary,
         continuous: continuous,
         blocking_failures: blocking,
         qualified: blocking == [],
         analysis_revision: program.analysis_revision,
         digest: digest({binary, continuous, blocking})
       }}
    else
      _invalid -> {:error, AdapterError.new(:invalid_input, :managed_coding_evaluation_results)}
    end
  end

  def score(_program, _trials),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_evaluation_results)}

  @spec task_classes() :: [atom()]
  def task_classes, do: @task_classes

  defp tasks(values) when is_list(values) and values != [] and length(values) <= 10_000 do
    normalized = Enum.sort_by(values, & &1.task_iri)

    valid =
      unique?(normalized, :task_iri) and Enum.all?(normalized, &valid_task?/1) and
        Enum.sort(Enum.uniq(Enum.map(normalized, & &1.task_class))) == Enum.sort(@task_classes)

    if valid, do: {:ok, normalized}, else: :error
  end

  defp tasks(_values), do: :error

  defp valid_task?(task) when is_map(task) do
    exact =
      Enum.sort(Map.keys(task)) ==
        Enum.sort([
          :task_iri,
          :revision,
          :base_revision,
          :repository_size,
          :language,
          :dependency_shape,
          :task_class,
          :conditions,
          :request_digest,
          :oracle_digest,
          :seed,
          :human_judgment
        ])

    exact and Identity.validate_resource(task.task_iri) == :ok and valid_digest?(task.revision) and
      valid_digest?(task.base_revision) and task.repository_size in [:small, :medium, :large] and
      is_binary(task.language) and is_binary(task.dependency_shape) and
      task.task_class in @task_classes and is_list(task.conditions) and
      Enum.all?(task.conditions, &(&1 in @conditions)) and valid_digest?(task.request_digest) and
      valid_digest?(task.oracle_digest) and is_integer(task.seed) and task.seed >= 0 and
      is_boolean(task.human_judgment)
  end

  defp valid_task?(_task), do: false

  defp thresholds(values) when is_map(values) do
    exact = Enum.sort(Map.keys(values)) == Enum.sort(@binary_metrics ++ @continuous_metrics)

    valid =
      Enum.all?(@binary_metrics, &(is_number(values[&1]) and values[&1] >= 0 and values[&1] <= 1)) and
        Enum.all?(@continuous_metrics, &(is_number(values[&1]) and values[&1] >= 0))

    if exact and valid, do: :ok, else: :error
  end

  defp thresholds(_values), do: :error

  defp baselines(values) when is_map(values) do
    if Enum.sort(Map.keys(values)) == Enum.sort(@binary_metrics) and
         Enum.all?(values, fn {_metric, value} ->
           is_number(value) and value >= 0 and value <= 1
         end),
       do: :ok,
       else: :error
  end

  defp baselines(_values), do: :error

  defp valid_trial?(trial, program) do
    assignment = Enum.find(plan(program), &(&1.trial_id == trial[:trial_id]))

    not is_nil(assignment) and trial[:profile_digest] == program.profile_digest and
      trial[:corpus_digest] == program.digest and
      Enum.all?(@binary_metrics, &is_boolean(trial[&1])) and
      Enum.all?(@continuous_metrics, &(is_integer(trial[&1]) and trial[&1] >= 0)) and
      (is_nil(trial[:failure_analysis]) or is_binary(trial[:failure_analysis]))
  end

  defp failure_reviews_complete?(trials) do
    Enum.all?(trials, fn trial ->
      passed = Enum.all?(@binary_metrics, &trial[&1])

      passed or
        (is_binary(trial.failure_analysis) and byte_size(trial.failure_analysis) in 1..2_000)
    end)
  end

  defp binary_metric(trials, metric) do
    numerator = Enum.count(trials, & &1[metric])
    Metrics.interval(numerator, length(trials))
  end

  defp continuous_metric(trials, metric) do
    values = Enum.map(trials, & &1[metric])
    mean = Enum.sum(values) / length(values)
    variance = Enum.reduce(values, 0.0, &(Float.pow(&1 - mean, 2) + &2)) / length(values)
    margin = 1.96 * :math.sqrt(variance / length(values))
    %{mean: mean, lower: max(0.0, mean - margin), upper: mean + margin, variance: variance}
  end

  defp blocking_failures(program, binary, continuous) do
    binary_failures =
      Enum.flat_map(@binary_metrics, fn metric ->
        interval = binary[metric]
        baseline_floor = program.baselines[metric] - program.regression_tolerance

        if interval.lower >= program.thresholds[metric] and interval.estimate >= baseline_floor,
          do: [],
          else: [{metric, :below_threshold_or_baseline}]
      end)

    continuous_failures =
      Enum.flat_map(@continuous_metrics, fn metric ->
        result = continuous[metric]

        cond do
          result.upper > program.thresholds[metric] -> [{metric, :above_threshold}]
          result.variance > program.maximum_variance -> [{metric, :variance_exceeded}]
          true -> []
        end
      end)

    sample_failures =
      if binary.task_correct.denominator >= program.minimum_sample_size,
        do: [],
        else: [{:sample_size, :insufficient}]

    binary_failures ++ continuous_failures ++ sample_failures
  end

  defp unique?(values, key),
    do: values |> Enum.map(& &1[key]) |> Enum.uniq() |> length() == length(values)

  defp valid_digest?(value), do: is_binary(value) and Regex.match?(@digest, value)

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid, do: {:error, AdapterError.new(:invalid_input, :managed_coding_evaluation_program)}
end
