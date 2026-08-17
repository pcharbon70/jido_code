defmodule JidoCode.Factory.Tool.Catalog do
  @moduledoc "Versioned closed catalog for the Phase 3 model-facing tool surface."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.Definition
  alias JidoCode.Factory.Tool.InputValidator

  @version "1.0.0"
  @names ~w[
    search_source inspect_symbol read_file apply_edit create_file delete_file
    run_registered_check run_governed_command show_candidate_diff submit_candidate
    request_clarification
  ]

  @spec all() :: [Definition.t()]
  def all do
    [
      definition(
        "search_source",
        "Search indexed source within one authorized scope.",
        schema([:query, :scope_ref], %{
          query: {:string, 1_024},
          scope_ref: :resource_iri,
          max_results: {:integer, 1, 100}
        }),
        read_output(),
        capability: :source_read,
        effect_class: :read,
        preconditions: [:scope_current, :source_revision_current],
        max_output_bytes: 65_536,
        adapter_identity: "JidoCode.Factory.Tools.SearchSource/1"
      ),
      definition(
        "inspect_symbol",
        "Inspect one symbol from an authorized source revision.",
        schema([:symbol, :source_ref, :expected_revision], %{
          symbol: {:string, 512},
          source_ref: :resource_iri,
          expected_revision: {:integer, 1, 9_223_372_036_854_775_807}
        }),
        read_output(),
        capability: :source_read,
        effect_class: :read,
        preconditions: [:source_revision_current],
        max_output_bytes: 65_536,
        adapter_identity: "JidoCode.Factory.Tools.InspectSymbol/1"
      ),
      definition(
        "read_file",
        "Read one repository-relative file at its expected digest.",
        schema([:path, :expected_digest], %{
          path: :relative_path,
          expected_digest: :digest,
          max_bytes: {:integer, 1, 262_144}
        }),
        read_output(),
        capability: :workspace_read,
        effect_class: :read,
        preconditions: [:snapshot_current, :path_authorized, :digest_current],
        max_output_bytes: 262_144,
        adapter_identity: "JidoCode.Factory.Tools.ReadFile/1"
      ),
      definition(
        "apply_edit",
        "Apply one unambiguous digest-guarded replacement.",
        schema([:path, :expected_digest, :old_text, :new_text, :expected_matches], %{
          path: :relative_path,
          expected_digest: :digest,
          old_text: {:text, 16_384},
          new_text: {:text, 16_384},
          expected_matches: {:integer, 1, 1}
        }),
        mutation_output(),
        capability: :workspace_write,
        effect_class: :write,
        preconditions: [:snapshot_current, :path_authorized, :digest_current, :fence_current],
        side_effects: [:workspace_mutation],
        reversibility: :reversible,
        idempotency_policy: :required,
        adapter_identity: "JidoCode.Factory.Tools.ApplyEdit/1"
      ),
      definition(
        "create_file",
        "Create one authorized repository-relative file without overwrite.",
        schema([:path, :content, :expected_parent_digest], %{
          path: :relative_path,
          content: {:text, 262_144},
          expected_parent_digest: :digest
        }),
        mutation_output(),
        capability: :workspace_write,
        effect_class: :write,
        preconditions: [:snapshot_current, :path_authorized, :target_absent, :fence_current],
        side_effects: [:workspace_mutation],
        reversibility: :reversible,
        idempotency_policy: :required,
        max_output_bytes: 32_768,
        adapter_identity: "JidoCode.Factory.Tools.CreateFile/1"
      ),
      definition(
        "delete_file",
        "Delete one authorized file at its expected digest.",
        schema([:path, :expected_digest], %{path: :relative_path, expected_digest: :digest}),
        mutation_output(),
        capability: :workspace_write,
        effect_class: :write,
        preconditions: [:snapshot_current, :path_authorized, :digest_current, :fence_current],
        side_effects: [:workspace_mutation],
        reversibility: :reversible,
        idempotency_policy: :required,
        max_output_bytes: 32_768,
        adapter_identity: "JidoCode.Factory.Tools.DeleteFile/1"
      ),
      definition(
        "run_registered_check",
        "Run a server-owned verification command selected by stable name.",
        schema([:check], %{check: {:string, 64}}),
        command_output(),
        capability: :check_execute,
        effect_class: :external,
        preconditions: [:command_registered, :sandbox_ready, :fence_current],
        side_effects: [:sandbox_process],
        reversibility: :not_applicable,
        retry_policy: :safe_idempotent,
        idempotency_policy: :required,
        timeout_ms: 300_000,
        max_output_bytes: 131_072,
        adapter_identity: "JidoCode.Factory.Tools.RegisteredCheck/1"
      ),
      definition(
        "run_governed_command",
        "Run a separately approved server-owned command contract; never raw shell.",
        schema([:command], %{command: {:string, 64}}),
        command_output(),
        capability: :governed_command_execute,
        effect_class: :external,
        preconditions: [:command_registered, :approval_current, :sandbox_ready, :fence_current],
        side_effects: [:sandbox_process],
        reversibility: :compensating,
        idempotency_policy: :required,
        approval_required: true,
        timeout_ms: 300_000,
        max_output_bytes: 131_072,
        adapter_identity: "JidoCode.Factory.Tools.GovernedCommand/1"
      ),
      definition(
        "show_candidate_diff",
        "Render the bounded candidate diff for one authorized snapshot.",
        schema([:snapshot_ref], %{snapshot_ref: :resource_iri, max_bytes: {:integer, 1, 262_144}}),
        read_output(),
        capability: :workspace_read,
        effect_class: :read,
        preconditions: [:snapshot_current],
        max_output_bytes: 262_144,
        adapter_identity: "JidoCode.Factory.Tools.ShowCandidateDiff/1"
      ),
      definition(
        "submit_candidate",
        "Submit an approved candidate to one allowlisted publication destination.",
        schema([:candidate_ref, :approval_ref, :destination, :expected_revision], %{
          candidate_ref: :resource_iri,
          approval_ref: :resource_iri,
          destination: {:string, 256},
          expected_revision: {:integer, 1, 9_223_372_036_854_775_807}
        }),
        publish_output(),
        capability: :candidate_publish,
        effect_class: :publish,
        preconditions: [
          :candidate_current,
          :approval_current,
          :destination_authorized,
          :fence_current
        ],
        side_effects: [:external_publication],
        reversibility: :compensating,
        retry_policy: :reconcile_first,
        idempotency_policy: :external_effect_id,
        approval_required: true,
        network_policy: {:allowlist, ["https://api.github.com"]},
        max_output_bytes: 32_768,
        adapter_identity: "JidoCode.Factory.Tools.SubmitCandidate/1"
      ),
      definition(
        "request_clarification",
        "Ask the controlling actor one bounded non-effecting clarification.",
        schema([:question, :reason], %{
          question: {:string, 2_048},
          reason: {:enum, ["missing_authority", "ambiguous_intent", "missing_input"]}
        }),
        schema([:status], %{status: {:enum, ["requested"]}, request_ref: :resource_iri}),
        capability: :interaction,
        effect_class: :external,
        preconditions: [:actor_session_current],
        side_effects: [:actor_notification],
        reversibility: :not_applicable,
        idempotency_policy: :required,
        max_output_bytes: 8_192,
        adapter_identity: "JidoCode.Factory.Tools.RequestClarification/1"
      )
    ]
  end

  @spec fetch(String.t(), String.t()) :: {:ok, Definition.t()} | {:error, AdapterError.t()}
  def fetch(name, version \\ @version)

  def fetch(name, version) when is_binary(name) and is_binary(version) do
    case Enum.find(all(), &(&1.name == name and &1.version == version)) do
      %Definition{} = definition -> {:ok, definition}
      nil -> {:error, AdapterError.new(:unauthorized, :tool_catalog)}
    end
  end

  def fetch(_name, _version), do: {:error, AdapterError.new(:invalid_input, :tool_catalog)}

  @spec validate(String.t(), String.t(), map(), map()) ::
          {:ok, {Definition.t(), map()}} | {:error, AdapterError.t()}
  def validate(name, version, arguments, constraints) do
    with {:ok, definition} <- fetch(name, version),
         {:ok, normalized} <- InputValidator.validate(definition, arguments, constraints) do
      {:ok, {definition, normalized}}
    end
  end

  @spec model_tools() :: [map()]
  def model_tools do
    Enum.map(all(), fn definition ->
      %{
        name: definition.name,
        version: definition.version,
        description: definition.description,
        input_schema: definition.input_schema,
        input_schema_digest: definition.input_schema_digest
      }
    end)
  end

  @spec names() :: [String.t()]
  def names, do: @names

  defp definition(name, description, input_schema, output_schema, options) do
    adapter = Keyword.fetch!(options, :adapter_identity)
    approval_required = Keyword.get(options, :approval_required, false)

    default_safe_errors = [
      :invalid_input,
      :unauthorized,
      :conflict,
      :unavailable,
      :timeout,
      :corrupt
    ]

    safe_errors =
      if approval_required,
        do: [:approval_required | default_safe_errors],
        else: default_safe_errors

    attributes = %{
      name: name,
      version: @version,
      description: description,
      input_schema: input_schema,
      input_schema_digest: Definition.digest(input_schema),
      output_schema: output_schema,
      output_schema_digest: Definition.digest(output_schema),
      capability: Keyword.fetch!(options, :capability),
      effect_class: Keyword.fetch!(options, :effect_class),
      preconditions: Keyword.get(options, :preconditions, []),
      side_effects: Keyword.get(options, :side_effects, []),
      reversibility: Keyword.get(options, :reversibility, :not_applicable),
      timeout_ms: Keyword.get(options, :timeout_ms, 30_000),
      retry_policy: Keyword.get(options, :retry_policy, :never),
      idempotency_policy: Keyword.get(options, :idempotency_policy, :read_only),
      max_output_bytes: Keyword.get(options, :max_output_bytes, 65_536),
      approval_required: approval_required,
      adapter_identity: adapter,
      adapter_digest: Definition.digest(adapter),
      network_policy: Keyword.get(options, :network_policy, :deny),
      safe_errors: Keyword.get(options, :safe_errors, safe_errors)
    }

    {:ok, definition} = Definition.new(attributes)
    definition
  end

  defp schema(required, properties),
    do: %{additional_properties: false, required: required, properties: properties}

  defp read_output do
    schema([:status, :content_digest], %{
      status: {:enum, ["completed"]},
      content_digest: :digest,
      content: {:text, 262_144},
      truncated: :boolean
    })
  end

  defp mutation_output do
    schema([:status, :effect_id, :result_digest], %{
      status: {:enum, ["completed", "rejected"]},
      effect_id: {:string, 128},
      result_digest: :digest
    })
  end

  defp command_output do
    schema([:status, :effect_id, :exit_status, :output_digest], %{
      status: {:enum, ["completed", "failed", "timed_out"]},
      effect_id: {:string, 128},
      exit_status: {:integer, 0, 255},
      output_digest: :digest
    })
  end

  defp publish_output do
    schema([:status, :effect_id, :external_ref], %{
      status: {:enum, ["completed", "ambiguous"]},
      effect_id: {:string, 128},
      external_ref: :resource_iri
    })
  end
end
