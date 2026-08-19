# Exact baseline for pre-existing Dialyzer findings.
#
# Keep entries specific: a changed or resolved warning makes
# `mix dialyzer --list-unused-filters` fail until this file is updated.
[
  {"lib/jido_code/architecture/checker.ex", "The pattern can never match the type Keyword.t()."},
  {"lib/jido_code/architecture/checker.ex",
   "The pattern variable _line@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/architecture/checker.ex",
   "The pattern variable __location@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/factory/delegated_result_gate.ex",
   "The pattern variable __invalid@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/factory/egress_broker.ex",
   "The pattern variable __invalid@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/factory/evaluation/adjudication.ex",
   "The pattern variable __invalid@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/factory/extensions/mcp/transport_adapter.ex",
   "Attempt to test for equality with an opaque type %MapSet{:map => MapSet.internal(_)}."},
  {"lib/jido_code/factory/extensions/registry.ex",
   "Attempt to test for equality with an opaque type %MapSet{:map => MapSet.internal(_)}."},
  {"lib/jido_code/factory/model/dispatch.ex",
   "The pattern pattern <__profile@1, __credential@1> can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/factory/sandbox/isolation_profile.ex",
   "Attempt to test for equality with an opaque type %MapSet{:map => MapSet.internal(_)}."},
  {"lib/jido_code/factory/sandbox/resource_enforcer.ex",
   "Attempt to test for equality with an opaque type %MapSet{:map => MapSet.internal(_)}."},
  {"lib/jido_code/factory/tool/proposal.ex",
   "Attempt to test for equality with an opaque type %MapSet{:map => MapSet.internal(_)}."},
  {"lib/jido_code/integrations/req_repository_provider.ex",
   "The pattern variable __invalid@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/integrations/req_repository_provider.ex",
   "The pattern can never match the type\s
  {:error,
   %JidoCode.Knowledge.Error{
     :__exception__ => true,
     :kind =>
       :conflict
       | :corrupt
       | :incompatible
       | :invalid_input
       | :locked
       | :persistence_failure
       | :stale_precondition
       | :timeout
       | :unauthorized
       | :unavailable,
     :message => binary(),
     :operation => atom(),
     :retry => :never | :refresh | :retry | :verify_receipt
   }}
."},
  {"lib/jido_code/integrations/req_repository_provider.ex",
   "Type mismatch in call without opaque term in member?."},
  {"lib/jido_code/knowledge/atomic_commit.ex", "The pattern can never match the type\s
  {:error,
   %JidoCode.Knowledge.Error{
     :__exception__ => true,
     :kind =>
       :conflict
       | :corrupt
       | :incompatible
       | :invalid_input
       | :locked
       | :persistence_failure
       | :stale_precondition
       | :timeout
       | :unauthorized
       | :unavailable,
     :message => <<_::64, _::size(8)>>,
     :operation => atom(),
     :retry => :never | :refresh | :retry | :verify_receipt
   }}
."},
  {"lib/jido_code/knowledge/atomic_commit.ex", "Function commit_new/3 will never be called."},
  {"lib/jido_code/knowledge/atomic_commit.ex",
   "Function validate_update_size/2 will never be called."},
  {"lib/jido_code/knowledge/atomic_commit.ex",
   "Function execute_and_reconcile/5 will never be called."},
  {"lib/jido_code/knowledge/atomic_commit.ex", "Function execute_update/2 will never be called."},
  {"lib/jido_code/knowledge/atomic_commit.ex",
   "Function reconcile_uncertain_result/3 will never be called."},
  {"lib/jido_code/knowledge/atomic_commit.ex", "Function compile_update/2 will never be called."},
  {"lib/jido_code/knowledge/atomic_commit.ex", "Function compile_insert/1 will never be called."},
  {"lib/jido_code/knowledge/atomic_commit.ex",
   "Function compile_graph_body/1 will never be called."},
  {"lib/jido_code/knowledge/atomic_commit.ex",
   "Function compile_delete_template/1 will never be called."},
  {"lib/jido_code/knowledge/atomic_commit.ex", "Function term/1 will never be called."},
  {"lib/jido_code/knowledge/backup.ex",
   "The pattern pattern {'error', __reason@1} can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/knowledge/backup.ex",
   "The pattern pattern {'error', _reason@2} can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/knowledge/command_outcome.ex", "The function call query will not succeed."},
  {"lib/jido_code/knowledge/command_outcome.ex", "Function decode/1 will never be called."},
  {"lib/jido_code/knowledge/command_outcome.ex", "Function corrupt/0 will never be called."},
  {"lib/jido_code/knowledge/commit_log.ex", "The function call query will not succeed."},
  {"lib/jido_code/knowledge/commit_log.ex", "Function decode/2 will never be called."},
  {"lib/jido_code/knowledge/commit_log.ex", "Function common_values/1 will never be called."},
  {"lib/jido_code/knowledge/commit_log.ex", "Function graph_revisions/1 will never be called."},
  {"lib/jido_code/knowledge/commit_log.ex", "Function confirm_absent/2 will never be called."},
  {"lib/jido_code/knowledge/commit_log.ex", "Function valid_digest?/1 will never be called."},
  {"lib/jido_code/knowledge/commit_log.ex",
   "Function valid_optional_digest?/1 will never be called."},
  {"lib/jido_code/knowledge/commit_log.ex", "Function integer_binding/2 will never be called."},
  {"lib/jido_code/knowledge/commit_log.ex", "Function string_binding/2 will never be called."},
  {"lib/jido_code/knowledge/commit_log.ex",
   "Function optional_string_binding/2 will never be called."},
  {"lib/jido_code/knowledge/commit_log.ex",
   "Function optional_iri_binding/2 will never be called."},
  {"lib/jido_code/knowledge/commit_log.ex", "Function iri_binding/2 will never be called."},
  {"lib/jido_code/knowledge/control/eligibility.ex",
   "The pattern variable __invalid@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/knowledge/control/harness_profile.ex",
   "The pattern variable __invalid@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/knowledge/control/obligation.ex",
   "The pattern variable __invalid@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/knowledge/control/reconciliation.ex",
   "The pattern variable __invalid@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/knowledge/control/transition.ex",
   "Invalid type specification for function statements."},
  {"lib/jido_code/knowledge/decision/follow_up.ex",
   "Invalid type specification for function statements."},
  {"lib/jido_code/knowledge/decision/goal_outcome.ex",
   "The pattern can never match the type true."},
  {"lib/jido_code/knowledge/derivation_request.ex",
   "The pattern variable __invalid@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/knowledge/evidence/bundle.ex", "The pattern can never match the type true."},
  {"lib/jido_code/knowledge/evidence/claim.ex",
   "Invalid type specification for function statements."},
  {"lib/jido_code/knowledge/execution/event_segment.ex",
   "The pattern variable __invalid@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/knowledge/execution/interaction_session.ex",
   "The pattern variable __invalid@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/knowledge/execution/model_invocation.ex",
   "The pattern variable __invalid@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/knowledge/graph_metadata.ex", "The function call query will not succeed."},
  {"lib/jido_code/knowledge/graph_metadata.ex", "Function read_rows/4 will never be called."},
  {"lib/jido_code/knowledge/graph_metadata.ex",
   "Function metadata_stage/3 will never be called."},
  {"lib/jido_code/knowledge/graph_metadata.ex", "Function decode_rows/2 will never be called."},
  {"lib/jido_code/knowledge/graph_metadata.ex", "Function put_decoded/3 will never be called."},
  {"lib/jido_code/knowledge/graph_metadata.ex",
   "Function normalize_decoded/2 will never be called."},
  {"lib/jido_code/knowledge/graph_metadata.ex",
   "Function complete_read_metadata?/1 will never be called."},
  {"lib/jido_code/knowledge/graph_metadata.ex", "Function decode_object/1 will never be called."},
  {"lib/jido_code/knowledge/graph_metadata.ex",
   "Function load_family_metadata/2 will never be called."},
  {"lib/jido_code/knowledge/graph_metadata.ex",
   "Function revision_query/2 will never be called."},
  {"lib/jido_code/knowledge/graph_metadata.ex",
   "Function load_revision_resources/3 will never be called."},
  {"lib/jido_code/knowledge/graph_metadata.ex",
   "Function decode_revision_resource/1 will never be called."},
  {"lib/jido_code/knowledge/graph_metadata.ex",
   "Function normalize_revision_resources/1 will never be called."},
  {"lib/jido_code/knowledge/integrity.ex", "Function check_backend/2 will never be called."},
  {"lib/jido_code/knowledge/integrity.ex", "Function check_dictionary/2 will never be called."},
  {"lib/jido_code/knowledge/integrity.ex", "Function check_metadata/3 will never be called."},
  {"lib/jido_code/knowledge/integrity.ex",
   "Function check_default_graph/2 will never be called."},
  {"lib/jido_code/knowledge/integrity.ex", "Function check_named_graphs/3 will never be called."},
  {"lib/jido_code/knowledge/integrity.ex",
   "Function check_commit_receipts/3 will never be called."},
  {"lib/jido_code/knowledge/integrity.ex", "Function check_receipt_row/4 will never be called."},
  {"lib/jido_code/knowledge/integrity.ex",
   "Function check_receipt_revisions/4 will never be called."},
  {"lib/jido_code/knowledge/integrity.ex", "Function commit_query/0 will never be called."},
  {"lib/jido_code/knowledge/integrity.ex", "Function issue/3 will never be called."},
  {"lib/jido_code/knowledge/integrity.ex", "Function bound_reference/1 will never be called."},
  {"lib/jido_code/knowledge/integrity.ex", "Function metadata_value/2 will never be called."},
  {"lib/jido_code/knowledge/maintenance.ex",
   "Unknown type: JidoCode.Knowledge.Retention.Receipt.t/0."},
  {"lib/jido_code/knowledge/memory/guardrails.ex", "The pattern can never match the type true."},
  {"lib/jido_code/knowledge/memory/state_transition.ex",
   "Invalid type specification for function statements."},
  {"lib/jido_code/knowledge/metadata.ex", "Invalid type specification for function ensure."},
  {"lib/jido_code/knowledge/metadata.ex", "Invalid type specification for function read."},
  {"lib/jido_code/knowledge/metadata.ex", "Function ensure/3 has no local return."},
  {"lib/jido_code/knowledge/metadata.ex", "Function read/1 has no local return."},
  {"lib/jido_code/knowledge/metadata.ex", "The function call read_base will not succeed."},
  {"lib/jido_code/knowledge/metadata.ex", "The function call latest_revision will not succeed."},
  {"lib/jido_code/knowledge/metadata.ex", "Function bootstrap_empty/3 will never be called."},
  {"lib/jido_code/knowledge/metadata.ex",
   "Function backend_graph_summary/1 will never be called."},
  {"lib/jido_code/knowledge/metadata.ex", "Function empty_dataset?/1 will never be called."},
  {"lib/jido_code/knowledge/metadata.ex", "Function validate/2 will never be called."},
  {"lib/jido_code/knowledge/metadata.ex", "Function read_base/1 has no local return."},
  {"lib/jido_code/knowledge/metadata.ex", "The function call query will not succeed."},
  {"lib/jido_code/knowledge/metadata.ex", "Function read_revisions/2 will never be called."},
  {"lib/jido_code/knowledge/metadata.ex", "Function decode_base/1 will never be called."},
  {"lib/jido_code/knowledge/metadata.ex", "Function latest_revision/4 has no local return."},
  {"lib/jido_code/knowledge/metadata.ex", "Function integer_binding/2 will never be called."},
  {"lib/jido_code/knowledge/metadata.ex", "Function iri_binding/2 will never be called."},
  {"lib/jido_code/knowledge/metadata.ex", "Function valid_lineage?/1 will never be called."},
  {"lib/jido_code/knowledge/metadata.ex", "Function bootstrap_update/2 will never be called."},
  {"lib/jido_code/knowledge/ontology/startup_gate.ex", "The pattern can never match the type\s
  {:error,
   %JidoCode.Knowledge.Error{
     :__exception__ => true,
     :kind =>
       :conflict
       | :corrupt
       | :incompatible
       | :invalid_input
       | :locked
       | :persistence_failure
       | :stale_precondition
       | :timeout
       | :unauthorized
       | :unavailable,
     :message => <<_::64, _::size(8)>>,
     :operation => atom(),
     :retry => :never | :refresh | :retry | :verify_receipt
   }}
."},
  {"lib/jido_code/knowledge/ontology/startup_gate.ex",
   "Function recognized_version?/3 will never be called."},
  {"lib/jido_code/knowledge/ontology/startup_gate.ex",
   "Function complete_enough?/1 will never be called."},
  {"lib/jido_code/knowledge/query_execution.ex",
   "The pattern pattern {'error', _reason@1} can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/knowledge/query_execution.ex",
   "The pattern variable __invalid@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/knowledge/query_execution.ex", "Function run/2 has no local return."},
  {"lib/jido_code/knowledge/query_execution.ex", "The function call query will not succeed."},
  {"lib/jido_code/knowledge/query_execution.ex", "Function decode/3 will never be called."},
  {"lib/jido_code/knowledge/query_execution.ex", "Function result/7 will never be called."},
  {"lib/jido_code/knowledge/query_execution.ex",
   "Function normalize_term/1 will never be called."},
  {"lib/jido_code/knowledge/query_execution.ex",
   "Function normalize_literal_value/1 will never be called."},
  {"lib/jido_code/knowledge/query_execution.ex",
   "Function enforce_bytes/2 will never be called."},
  {"lib/jido_code/knowledge/query_execution.ex",
   "Function single_or_unknown/1 will never be called."},
  {"lib/jido_code/knowledge/query_execution.ex", "Function freshness/2 will never be called."},
  {"lib/jido_code/knowledge/reasoning/service.ex",
   "The pattern can never match the type false | {:ok, atom()}."},
  {"lib/jido_code/knowledge/repositories/enrollment.ex",
   "The pattern variable __invalid@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/knowledge/repositories/enrollment_transition.ex",
   "Invalid type specification for function statements."},
  {"lib/jido_code/knowledge/resource_identity.ex",
   "The pattern variable __invalid@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/knowledge/retention/restore_guard.ex",
   "Invalid type specification for function floor."},
  {"lib/jido_code/knowledge/retention/restore_guard.ex", "Function floor/1 has no local return."},
  {"lib/jido_code/knowledge/retention/restore_guard.ex",
   "The function call query will not succeed."},
  {"lib/jido_code/knowledge/retention/restore_guard.ex",
   "Function decode_floor/1 will never be called."},
  {"lib/jido_code/knowledge/revision.ex", "The pattern can never match the type\s
  {:error,
   %JidoCode.Knowledge.Error{
     :__exception__ => true,
     :kind =>
       :conflict
       | :corrupt
       | :incompatible
       | :invalid_input
       | :locked
       | :persistence_failure
       | :stale_precondition
       | :timeout
       | :unauthorized
       | :unavailable,
     :message => <<_::64, _::size(8)>>,
     :operation => atom(),
     :retry => :never | :refresh | :retry | :verify_receipt
   }}
."},
  {"lib/jido_code/knowledge/revision.ex",
   "Function ensure_unmanaged_graph_empty/2 will never be called."},
  {"lib/jido_code/knowledge/semantic_snapshot.ex", "The pattern can never match the type\s
  {:error,
   %JidoCode.Knowledge.Error{
     :__exception__ => true,
     :kind =>
       :conflict
       | :corrupt
       | :incompatible
       | :invalid_input
       | :locked
       | :persistence_failure
       | :stale_precondition
       | :timeout
       | :unauthorized
       | :unavailable,
     :message => <<_::64, _::size(8)>>,
     :operation => atom(),
     :retry => :never | :refresh | :retry | :verify_receipt
   }}
."},
  {"lib/jido_code/knowledge/semantic_snapshot.ex",
   "The pattern variable __invalid@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/knowledge/store_server.ex",
   "The pattern pattern {'error', _reason@1} can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/knowledge/store_server.ex", "The pattern can never match the type\s
  {:error,
   %JidoCode.Knowledge.Error{
     :__exception__ => true,
     :kind =>
       :conflict
       | :corrupt
       | :incompatible
       | :invalid_input
       | :locked
       | :persistence_failure
       | :stale_precondition
       | :timeout
       | :unauthorized
       | :unavailable,
     :message => <<_::64, _::size(8)>>,
     :operation => atom(),
     :retry => :never | :refresh | :retry | :verify_receipt
   }}
."},
  {"lib/jido_code/knowledge/store_server.ex", "The pattern can never match the type\s
  {:error,
   %JidoCode.Knowledge.Error{
     :__exception__ => true,
     :kind =>
       :conflict
       | :corrupt
       | :incompatible
       | :invalid_input
       | :locked
       | :persistence_failure
       | :stale_precondition
       | :timeout
       | :unauthorized
       | :unavailable,
     :message => binary(),
     :operation => atom(),
     :retry => :never | :refresh | :retry | :verify_receipt
   }}
  | {:error,
     %JidoCode.Knowledge.Error{
       :__exception__ => true,
       :kind =>
         :conflict
         | :corrupt
         | :incompatible
         | :invalid_input
         | :locked
         | :persistence_failure
         | :stale_precondition
         | :timeout
         | :unauthorized
         | :unavailable,
       :message => <<_::64, _::size(8)>>,
       :operation => atom(),
       :retry => :never | :refresh | :retry | :verify_receipt
     },
     %JidoCode.Knowledge.ConsistencyReceipt{
       :complete_graphs => [any()],
       :constraint_digest => binary(),
       :dataset_revision => _,
       :derived_rule_set_revision => _,
       :gaps => [any()],
       :graph_revisions => _,
       :mode => _,
       :ontology_version => _,
       :status => :degraded | :satisfied,
       :valid_at => _,
       :valid_interval => _
     }}
."},
  {"lib/jido_code/knowledge/store_server.ex",
   "Function restore_candidate/2 has no local return."},
  {"lib/jido_code/knowledge/store_server.ex",
   "Function restore_staged_candidate/5 will never be called."},
  {"lib/jido_code/knowledge/store_server.ex",
   "Function open_validated_candidate/3 will never be called."},
  {"lib/jido_code/knowledge/store_server.ex",
   "Function activate_restored_candidate/7 will never be called."},
  {"lib/jido_code/knowledge/store_server.ex",
   "Function validate_activated_store/6 will never be called."},
  {"lib/jido_code/knowledge/store_server.ex",
   "Function rollback_restore/5 will never be called."},
  {"lib/jido_code/knowledge/store_server.ex",
   "Function open_validated_rollback/3 will never be called."},
  {"lib/jido_code/knowledge/store_server.ex", "Function finish_restore/2 will never be called."},
  {"lib/jido_code/knowledge/store_server.ex",
   "Function close_candidate_error/2 will never be called."},
  {"lib/jido_code/knowledge/store_server.ex",
   "Function close_owned_store/1 will never be called."},
  {"lib/jido_code/knowledge/store_server.ex",
   "Function manifest_metadata/1 will never be called."},
  {"lib/jido_code/knowledge/store_server.ex",
   "Function verify_expected_metadata/2 will never be called."},
  {"lib/jido_code/knowledge/store_server.ex",
   "Function verify_restore_increment/2 will never be called."},
  {"lib/jido_code/knowledge/temporal_selection.ex",
   "The pattern variable __invalid@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/runtime/jido_adapter.ex",
   "The pattern variable __error@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/runtime/jido_harness/developer_local_launch.ex",
   "Attempt to test for equality with an opaque type %MapSet{:map => MapSet.internal(_)}."},
  {"lib/jido_code/runtime/jido_harness/process_runner.ex",
   "The pattern pattern {'error', _reason@1} can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/runtime/jido_harness/process_runner.ex",
   "The pattern variable __invalid@1 can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/runtime/jido_harness/readiness.ex",
   "The pattern pattern <__profile@1, __status@1> can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/runtime/jido_harness_adapter.ex",
   "The pattern pattern <__request@1, __record@1, __receipt@1, __options@1> can never match the type, because it is covered by previous clauses."},
  {"lib/jido_code/security/redactor.ex", "Unknown type: JidoCode.Security.RedactionReceipt.t/0."},
  {"lib/jido_code_web/frontend_assets.ex", "Unknown type: PhoenixVite.Manifest.t/0."},
  {"lib/mix/tasks/jido_code.ontology.ex", "Function fail/1 has no local return."}
]
