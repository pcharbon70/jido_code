defmodule JidoCode.Security.DataPolicy do
  @moduledoc """
  Closed memory data-classification policy shared by durable placement,
  product output, export, provider egress, and retention boundaries.
  """

  alias JidoCode.Knowledge.GraphRegistry

  @revision "2.0.0"

  @classifications [
    :public,
    :internal,
    :confidential,
    :secret_reference,
    :secret_value,
    :source_body,
    :prompt,
    :prompt_representation,
    :interaction_content,
    :model_result,
    :tool_output,
    :artifact_content,
    :integrity_commitment,
    :evidence_record,
    :accepted_knowledge,
    :experience_record,
    :lifecycle_record,
    :encrypted_content,
    :export_derivative,
    :backup_derivative,
    :personal,
    :audit
  ]

  @representations ~w[
    semantic_metadata normalized_text digest redacted_text external_reference exact_text
    ciphertext ciphertext_commitment keyed_commitment legacy_unkeyed_digest none
  ]a

  @profiles %{
    semantic_history: %{
      enabled: true,
      purpose: :managed_continuity,
      exact_prompt: :omit,
      raw_provider_response: :omit,
      raw_tool_body: :omit,
      activation_gate: :accepted
    },
    diagnostic_capture: %{
      enabled: false,
      purpose: :bounded_diagnostics,
      activation_gate: :superseding_privacy_contract
    },
    project_total_history: %{
      enabled: false,
      purpose: :project_memory,
      activation_gate: :accepted_diagnostic_evaluation
    },
    incident_hold: %{
      enabled: false,
      purpose: :case_scoped_hold,
      activation_gate: :dual_approval_and_periodic_review
    }
  }

  @dimensions %{
    capture_outcome: ~w[captured omitted unavailable redacted failed expired erased]a,
    representation: @representations,
    storage_location: ~w[
      ontology_graph catalog_graph policy_graph observation_graph source_graph control_graph
      run_graph run_event_segment_graph evidence_graph memory_graph experience_graph
      content_lifecycle_graph episode_content_graph security_audit_graph derived_graph
      governed_artifact external_provider omitted
    ]a,
    availability: ~w[available cold pending unavailable failed]a,
    retention: ~w[
      active archive_eligible archived expired erasure_pending cryptographically_erased
      physically_deleted externally_unverifiable
    ]a,
    hold: ~w[not_held held release_pending]a
  }

  @rules %{
    public: %{
      graphs: [:ontology],
      representations: [:semantic_metadata, :normalized_text, :digest],
      outputs: [:ui, :docs, :telemetry, :approved_export],
      provider_egress: [:approved]
    },
    internal: %{
      graphs: [
        :factory_catalog,
        :repository_control,
        :run_attempt,
        :run_event_segment,
        :derived
      ],
      representations: [:semantic_metadata, :normalized_text, :digest, :external_reference],
      outputs: [:authorized_ui, :audit, :bounded_artifact, :approved_export],
      provider_egress: [:approved]
    },
    confidential: %{
      graphs: [:observation_batch, :source_revision, :run_attempt, :run_event_segment],
      representations: [:semantic_metadata, :normalized_text, :digest, :external_reference],
      outputs: [:authorized_ui, :audit, :bounded_artifact, :approved_export],
      provider_egress: [:approved_restricted]
    },
    secret_reference: %{
      graphs: [:factory_policy, :episode_content],
      representations: [:semantic_metadata, :external_reference],
      outputs: [:authorized_ui, :audit],
      provider_egress: []
    },
    secret_value: %{
      graphs: [],
      representations: [],
      outputs: [],
      provider_egress: []
    },
    source_body: %{
      graphs: [:source_revision],
      representations: [:digest, :external_reference],
      outputs: [:bounded_artifact, :approved_export],
      provider_egress: [:approved_restricted]
    },
    prompt: %{graphs: [], representations: [], outputs: [], provider_egress: []},
    prompt_representation: %{
      graphs: [:run_attempt],
      representations: [:normalized_text, :digest, :legacy_unkeyed_digest],
      outputs: [:authorized_ui, :audit],
      provider_egress: []
    },
    interaction_content: %{
      graphs: [:repository_control, :run_attempt, :run_event_segment],
      representations: [:normalized_text, :redacted_text, :digest],
      outputs: [:authorized_ui, :audit],
      provider_egress: [:approved_restricted]
    },
    model_result: %{
      graphs: [:run_attempt, :run_event_segment],
      representations: [:semantic_metadata, :normalized_text, :digest, :external_reference],
      outputs: [:authorized_ui, :audit, :bounded_artifact],
      provider_egress: []
    },
    tool_output: %{
      graphs: [:run_attempt],
      representations: [:exact_text, :digest, :external_reference, :legacy_unkeyed_digest],
      outputs: [:bounded_artifact],
      provider_egress: []
    },
    artifact_content: %{
      graphs: [:run_attempt, :run_event_segment, :episode_content],
      representations: [:exact_text, :digest, :external_reference, :ciphertext],
      outputs: [:bounded_artifact, :approved_export],
      provider_egress: [:approved_restricted]
    },
    integrity_commitment: %{
      graphs: [:security_audit],
      representations: [:ciphertext_commitment, :keyed_commitment, :legacy_unkeyed_digest],
      outputs: [:authorized_audit],
      provider_egress: []
    },
    evidence_record: %{
      graphs: [:evidence],
      representations: [:semantic_metadata, :normalized_text, :digest, :external_reference],
      outputs: [:authorized_ui, :audit, :approved_export],
      provider_egress: [:approved]
    },
    accepted_knowledge: %{
      graphs: [:memory],
      representations: [:semantic_metadata, :normalized_text, :digest],
      outputs: [:authorized_ui, :audit, :approved_export],
      provider_egress: [:approved]
    },
    experience_record: %{
      graphs: [:experience],
      representations: [:semantic_metadata, :normalized_text, :digest, :external_reference],
      outputs: [:authorized_ui, :audit, :approved_export],
      provider_egress: [:approved]
    },
    lifecycle_record: %{
      graphs: [:content_lifecycle],
      representations: [:semantic_metadata, :digest, :external_reference],
      outputs: [:authorized_ui, :authorized_audit],
      provider_egress: []
    },
    encrypted_content: %{
      graphs: [:episode_content],
      representations: [:ciphertext, :digest, :external_reference],
      outputs: [:content_gateway],
      provider_egress: []
    },
    export_derivative: %{
      graphs: [],
      representations: [:external_reference, :digest],
      outputs: [:authorized_audit],
      provider_egress: []
    },
    backup_derivative: %{
      graphs: [],
      representations: [:external_reference, :digest],
      outputs: [:authorized_audit],
      provider_egress: []
    },
    personal: %{
      graphs: [:security_audit],
      representations: [:semantic_metadata, :redacted_text, :ciphertext],
      outputs: [:authorized_audit],
      provider_egress: []
    },
    audit: %{
      graphs: [:security_audit],
      representations: [:semantic_metadata, :normalized_text, :digest, :external_reference],
      outputs: [:authorized_audit],
      provider_egress: []
    }
  }

  @sensitive_keys ~w[
    access_token api_key authorization bearer client_secret cookie credential
    password private_key prompt secret session source_body stdout stderr token
  ]

  @spec classifications() :: [atom()]
  def classifications, do: @classifications

  @spec revision() :: String.t()
  def revision, do: @revision

  @spec profiles() :: [atom()]
  def profiles, do: @profiles |> Map.keys() |> Enum.sort()

  @spec profile(atom()) :: {:ok, map()} | :error
  def profile(name) when is_atom(name), do: Map.fetch(@profiles, name)
  def profile(_name), do: :error

  @spec profile_enabled?(atom()) :: boolean()
  def profile_enabled?(name), do: match?({:ok, %{enabled: true}}, profile(name))

  @spec dimensions() :: map()
  def dimensions, do: @dimensions

  @spec rule(atom()) :: {:ok, map()} | :error
  def rule(classification) when classification in @classifications,
    do: {:ok, Map.fetch!(@rules, classification)}

  def rule(_classification), do: :error

  @spec classify_key(String.t() | atom()) :: atom()
  def classify_key(key) do
    normalized = key |> to_string() |> String.downcase()

    if Enum.any?(@sensitive_keys, &String.contains?(normalized, &1)),
      do: :secret_value,
      else: :internal
  end

  @spec durable_allowed?(atom(), atom()) :: boolean()
  def durable_allowed?(classification, graph_family) do
    case rule(classification) do
      {:ok, %{graphs: graphs}} -> graph_family in graphs
      :error -> false
    end
  end

  @spec durable_allowed?(atom(), atom(), atom(), atom()) :: boolean()
  def durable_allowed?(classification, graph_family, representation, profile) do
    with true <- profile_enabled?(profile),
         {:ok, %{graphs: graphs, representations: representations}} <- rule(classification),
         true <- graph_family in graphs,
         true <- representation in representations,
         true <- profile_representation_allowed?(profile, classification, representation),
         {:ok, %{enabled: enabled}} <- GraphRegistry.fetch(graph_family) do
      enabled
    else
      _denied -> false
    end
  end

  @spec output_allowed?(atom(), atom()) :: boolean()
  def output_allowed?(classification, sink) do
    case rule(classification) do
      {:ok, %{outputs: outputs}} -> sink in outputs
      :error -> false
    end
  end

  @spec provider_egress_allowed?(atom(), atom()) :: boolean()
  def provider_egress_allowed?(classification, posture) do
    case rule(classification) do
      {:ok, %{provider_egress: allowed}} -> posture in allowed
      :error -> false
    end
  end

  @spec new_commitment_allowed?(atom(), atom(), map()) :: boolean()
  def new_commitment_allowed?(:ciphertext_commitment, classification, attributes) do
    classification != :secret_value and attributes[:encrypted_before_commit] == true
  end

  def new_commitment_allowed?(:keyed_commitment, classification, attributes) do
    classification != :secret_value and attributes[:purpose] == :equality_verification and
      attributes[:key_location] == :external
  end

  def new_commitment_allowed?(_kind, _classification, _attributes), do: false

  @spec verify() :: :ok | :error
  def verify do
    classified = Map.keys(@rules) |> Enum.sort()
    enabled = Enum.filter(@profiles, fn {_name, profile} -> profile.enabled end)

    covered_families =
      @rules
      |> Map.values()
      |> Enum.flat_map(& &1.graphs)
      |> MapSet.new()

    if classified == Enum.sort(@classifications) and
         enabled == [semantic_history: @profiles.semantic_history] and
         MapSet.subset?(MapSet.new(GraphRegistry.families()), covered_families) and
         Enum.all?(@rules, fn {_classification, rule} ->
           Enum.all?(rule.representations, &(&1 in @representations))
         end) do
      :ok
    else
      :error
    end
  end

  defp profile_representation_allowed?(:semantic_history, :tool_output, :exact_text),
    do: false

  defp profile_representation_allowed?(:semantic_history, _classification, _representation),
    do: true

  defp profile_representation_allowed?(_profile, _classification, _representation), do: false
end
