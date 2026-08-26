defmodule JidoCode.Knowledge.Retention.Policy do
  @moduledoc "Closed retention policy for every authoritative graph data family."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry

  @classes %{
    permanent: %{minimum_days: :infinity, disposition: :retain},
    observations: %{minimum_days: 90, disposition: :archive},
    source_history: %{minimum_days: 365, disposition: :archive},
    control_history: %{minimum_days: 2_555, disposition: :archive},
    run_history: %{minimum_days: 180, disposition: :archive},
    experience_history: %{minimum_days: 2_555, disposition: :archive},
    content_lifecycle: %{minimum_days: 2_555, disposition: :archive},
    governed_content: %{minimum_days: :infinity, disposition: :retain},
    dataset_lifecycle: %{minimum_days: 2_555, disposition: :archive},
    wiki_edition: %{minimum_days: 365, disposition: :archive},
    semantic_shell: %{minimum_days: 2_555, disposition: :archive},
    exact_payload: %{minimum_days: 30, disposition: :archive},
    evidence_history: %{minimum_days: 2_555, disposition: :archive},
    knowledge_history: %{minimum_days: 2_555, disposition: :archive},
    security_audit: %{minimum_days: 2_555, disposition: :archive},
    disposable: %{minimum_days: 0, disposition: :remove}
  }

  @supplemental %{
    command_receipt: :security_audit,
    validation_report: :security_audit,
    decision: :evidence_history,
    accepted_knowledge: :knowledge_history,
    desired_outcome: :control_history,
    goal: :control_history,
    policy: :permanent,
    audit: :security_audit,
    capture_manifest: :semantic_shell,
    content_capture: :semantic_shell,
    episode_content: :exact_payload,
    memory_dataset: :dataset_lifecycle,
    wiki_edition: :wiki_edition,
    wiki_preview: :disposable,
    derived_cache: :disposable
  }

  @spec classes() :: map()
  def classes, do: @classes

  @spec supplemental_classes() :: map()
  def supplemental_classes, do: @supplemental

  @spec class_for_family(atom()) :: {:ok, atom()} | {:error, Error.t()}
  def class_for_family(family) do
    with {:ok, contract} <- GraphRegistry.fetch(family),
         true <- Map.has_key?(@classes, contract.retention) do
      {:ok, contract.retention}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :retention_class)}
    end
  end

  @spec class_for_resource(atom()) :: {:ok, atom()} | {:error, Error.t()}
  def class_for_resource(kind) when is_atom(kind) do
    case Map.fetch(@supplemental, kind) do
      {:ok, class} -> {:ok, class}
      :error -> {:error, Error.new(:invalid_input, :retention_resource_kind)}
    end
  end

  def class_for_resource(_kind),
    do: {:error, Error.new(:invalid_input, :retention_resource_kind)}

  @spec disposition(atom(), non_neg_integer()) ::
          {:ok, :retain | :archive | :remove} | {:error, Error.t()}
  def disposition(class, age_days)
      when is_atom(class) and is_integer(age_days) and age_days >= 0 do
    case Map.fetch(@classes, class) do
      {:ok, %{minimum_days: :infinity}} -> {:ok, :retain}
      {:ok, %{minimum_days: days}} when age_days < days -> {:ok, :retain}
      {:ok, %{disposition: disposition}} -> {:ok, disposition}
      :error -> {:error, Error.new(:invalid_input, :retention_class)}
    end
  end

  def disposition(_class, _age_days),
    do: {:error, Error.new(:invalid_input, :retention_policy)}

  @spec verify() :: :ok | {:error, Error.t()}
  def verify do
    covered? =
      Enum.all?(GraphRegistry.families(), fn family ->
        match?({:ok, _class}, class_for_family(family))
      end)

    if covered? and
         Enum.all?(@supplemental, fn {_kind, class} -> Map.has_key?(@classes, class) end),
       do: :ok,
       else: {:error, Error.new(:incompatible, :retention_policy)}
  end
end
