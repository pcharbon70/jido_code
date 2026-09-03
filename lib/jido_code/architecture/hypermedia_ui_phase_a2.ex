defmodule JidoCode.Architecture.HypermediaUIPhaseA2 do
  @moduledoc false

  alias JidoCode.Knowledge.Authorization
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.QueryCatalog

  @manifest_directory "priv/architecture/hypermedia_ui"
  @manifest_files %{
    identity: "phase_a2_identity_and_assurance.json",
    matrix: "phase_a2_authorization_matrix.json",
    approval: "phase_a2_approval_and_revocation.json",
    scenarios: "phase_a2_policy_scenarios.json"
  }
  @baseline_commit "133b66187828668b61a65b4d2ab5a9033fe56a15"
  @implementation_commit "e4e213874e19086ab1164b55558edcb9348586e8"
  @merged_candidate "911b8d7c8a25abf998af832f7ae8e6766e971962"
  @merged_date "2026-09-03"

  @principal_classes ~w[human service agent]
  @identity_records ~w[
    human_account authenticator browser_session authentication_event recovery_event audit_event
  ]
  @assurance_levels ~w[baseline phishing_resistant action_bound_step_up]
  @exceptional_flows ~w[bootstrap recovery break_glass identity_provider_outage]
  @roles ~w[
    observer project_developer project_maintainer independent_verifier factory_operator
    security_auditor factory_administrator knowledge_steward cost_observer
  ]
  @surfaces ~w[
    page fragment query field search detail stream patch command export download approval incident
  ]
  @outcomes ~w[
    allowed concealed_not_found redacted denied unavailable revoked step_up_required
  ]
  @binding_dimensions ~w[
    subject_and_session current_account_status tenant_and_project_membership exact_graph_grant
    exact_optional_delegation assurance_and_authentication_age resource_containment classification
    environment lifecycle policy_revision graph_revisions incident_posture fence_when_applicable
  ]
  @reauthorization_points ~w[
    before_response_start before_query_execution before_field_shaping before_stream_subscription
    before_each_protected_patch before_command_construction inside_command_gateway
    before_approval_commit before_export_creation before_each_export_or_download_retrieval
  ]
  @approval_states ~w[pending quorum_met rejected expired invalidated committed]
  @approval_transitions ~w[record_unique_approval reject expire invalidate commit]
  @commit_outcomes ~w[winner idempotent_duplicate conflict_loser stale_or_revoked]
  @revocation_dimensions ~w[account session role delegation project tenant graph incident]
  @delivery_states ~w[
    active revocation_observed terminal_replacement closed reconnect_suppressed
  ]
  @terminal_client_actions ~w[
    stop_future_protected_delivery best_effort_replace_protected_fragment close_stream
    suppress_privileged_reconnect invalidate_signed_links
    invalidate_export_and_download_retrieval clear_privileged_browser_state
    record_safe_security_and_audit_evidence
  ]
  @threats ~w[
    HUI-T02-IDOR HUI-T02-ROLE-UNION HUI-T02-DELEGATION HUI-T02-ASSURANCE
    HUI-T02-APPROVAL HUI-T02-CONCURRENCY HUI-T02-REVOCATION HUI-T02-EXPORT
    HUI-T02-CONCEALMENT
  ]
  @required_docs ~w[
    docs/adr/0009-human-identity-scoped-authorization-and-separation-of-duty.md
    docs/architecture/README.md
    docs/architecture/human-identity-scope-and-authorization-contract.md
    docs/architecture/hypermedia-ui-operation-authorization-matrix.md
    docs/architecture/hypermedia-ui-approval-and-live-revocation-authority.md
    docs/architecture/hypermedia-ui-milestone-a-phase-02-receipt.md
    docs/architecture/ui-security-privacy-and-threat-model.md
    docs/planning/secure-hypermedia-control-plane-ui/milestone-a-architectural-authority/phase-02-human-identity-and-authorization-authority.md
  ]

  @type manifests :: %{
          identity: map(),
          matrix: map(),
          approval: map(),
          scenarios: map()
        }

  @spec check(Path.t()) :: {:ok, []} | {:error, [String.t()]}
  def check(root \\ File.cwd!()) do
    case load(root) do
      {:ok, manifests} ->
        case validate(manifests, root) do
          [] -> {:ok, []}
          errors -> {:error, errors}
        end

      {:error, errors} ->
        {:error, errors}
    end
  end

  @spec load(Path.t()) :: {:ok, manifests()} | {:error, [String.t()]}
  def load(root \\ File.cwd!()) do
    {manifests, errors} =
      Enum.reduce(@manifest_files, {%{}, []}, fn {key, file}, {loaded, errors} ->
        path = Path.join([root, @manifest_directory, file])

        case File.read(path) do
          {:ok, body} ->
            case Jason.decode(body) do
              {:ok, manifest} -> {Map.put(loaded, key, manifest), errors}
              {:error, reason} -> {loaded, ["#{path}: invalid JSON: #{inspect(reason)}" | errors]}
            end

          {:error, reason} ->
            {loaded, ["#{path}: cannot read manifest: #{inspect(reason)}" | errors]}
        end
      end)

    if errors == [], do: {:ok, manifests}, else: {:error, Enum.reverse(errors)}
  end

  @spec validate(manifests(), Path.t()) :: [String.t()]
  def validate(
        %{identity: identity, matrix: matrix, approval: approval, scenarios: scenarios},
        root
      ) do
    []
    |> validate_identity(identity, root)
    |> validate_matrix(matrix)
    |> validate_approval(approval)
    |> validate_scenarios(matrix, approval, scenarios)
    |> validate_documents(root)
    |> Enum.reverse()
  end

  def validate(_incomplete, _root), do: ["HUI-A2 manifest set is incomplete"]

  @spec evaluate_authorization(map(), map(), map()) :: String.t()
  def evaluate_authorization(matrix, defaults, scenario) do
    operation = Enum.find(matrix["operations"] || [], &(&1["id"] == scenario["operation_id"]))
    context = Map.merge(defaults || %{}, scenario["overrides"] || %{})

    cond do
      is_nil(operation) ->
        "invalid_scenario"

      operation["binding"]["status"] == "future_contract_only" ->
        "unavailable"

      context["account_active"] != true or context["session_current"] != true ->
        "revoked"

      context["adapter_composed"] != true ->
        "unavailable"

      concealed_failure?(context) ->
        if context["concealed"] == true, do: "concealed_not_found", else: "denied"

      context["assurance_current"] != true ->
        if context["concealed"] == true and context["resource_exists"] != true,
          do: "concealed_not_found",
          else: "step_up_required"

      context["classification_allowed"] != true ->
        if operation["surface"] == "field" and context["enclosing_resource_authorized"] == true,
          do: "redacted",
          else: "denied"

      decision_stale?(context) ->
        "denied"

      true ->
        "allowed"
    end
  end

  @spec evaluate_approval(map()) :: String.t()
  def evaluate_approval(%{"event" => "approve"} = scenario) do
    checkers = scenario["checker_refs"] || []
    eligible = MapSet.new(scenario["eligible_checker_refs"] || [])
    unique_checkers = Enum.uniq(checkers)

    cond do
      scenario["state"] != "pending" -> "denied"
      scenario["before_expiry"] != true -> "expired"
      scenario["request_current"] != true -> "invalidated"
      scenario["assurance_current"] != true -> "denied"
      scenario["maker_ref"] in unique_checkers -> "denied"
      not Enum.all?(unique_checkers, &MapSet.member?(eligible, &1)) -> "denied"
      length(unique_checkers) >= scenario["required_checker_count"] -> "quorum_met"
      true -> "pending"
    end
  end

  def evaluate_approval(%{"event" => "expire", "state" => state})
      when state in ["pending", "quorum_met"],
      do: "expired"

  def evaluate_approval(%{"event" => "invalidate", "state" => state})
      when state in ["pending", "quorum_met"],
      do: "invalidated"

  def evaluate_approval(%{"event" => "commit", "state" => "quorum_met"} = scenario) do
    cond do
      scenario["revoked"] == true -> "stale_or_revoked"
      scenario["request_current"] != true -> "stale_or_revoked"
      scenario["cas_outcome"] in @commit_outcomes -> scenario["cas_outcome"]
      true -> "denied"
    end
  end

  def evaluate_approval(_scenario), do: "denied"

  @spec evaluate_revocation(map(), map()) :: String.t()
  def evaluate_revocation(approval, %{"kind" => "generation_event"} = scenario) do
    dimensions = Enum.map(approval["revocation_dimensions"] || [], & &1["id"])

    if scenario["dimension"] in dimensions and
         scenario["next_generation"] == scenario["prior_generation"] + 1,
       do: "revocation_observed",
       else: "denied"
  end

  def evaluate_revocation(approval, %{"kind" => "delivery_sequence"} = scenario) do
    transitions = approval["protected_delivery_transitions"] || []

    Enum.reduce_while(scenario["events"] || [], scenario["initial_state"], fn event, state ->
      case Enum.find(transitions, &(&1["from"] == state and &1["event"] == event)) do
        nil -> {:halt, "invalid_transition"}
        transition -> {:cont, transition["to"]}
      end
    end)
  end

  def evaluate_revocation(_approval, %{"kind" => "retrieval"} = scenario) do
    if scenario["generation_current"] == true, do: "allowed", else: "revoked"
  end

  def evaluate_revocation(_approval, %{"kind" => "offline_limit"}),
    do: "cannot_erase_prior_bytes"

  def evaluate_revocation(_approval, _scenario), do: "invalid_scenario"

  defp validate_identity(errors, identity, root) do
    errors =
      errors
      |> require_equal(identity["schema_version"], 1, "identity schema_version must be 1")
      |> require_equal(identity["phase"], "HUI-A2", "identity phase must be HUI-A2")
      |> require_equal(
        get_in(identity, ["baseline", "commit"]),
        @baseline_commit,
        "identity baseline must pin the HUI-A1 closure merge"
      )
      |> require_equal(
        get_in(identity, ["decision", "status"]),
        "accepted_architecture_authority",
        "ADR 0009 must be accepted as architecture authority"
      )
      |> require_equal(
        get_in(identity, ["decision", "runtime_status"]),
        "unavailable_until_later_gates",
        "named-human runtime must remain unavailable"
      )
      |> require_exact_ids(
        identity["principal_classes"],
        @principal_classes,
        "principal class"
      )
      |> require_exact_ids(identity["identity_records"], @identity_records, "identity record")
      |> require_exact_ids(identity["assurance_levels"], @assurance_levels, "assurance level")
      |> require_exact_ids(identity["exceptional_flows"], @exceptional_flows, "exceptional flow")

    errors =
      Enum.reduce(identity["identity_records"] || [], errors, fn record, acc ->
        acc
        |> require_text(record["immutable_reference"], "#{record["id"]} immutable_reference")
        |> require_nonempty(record["required_fields"], "#{record["id"]} required_fields")
        |> require_nonempty(record["prohibited_fields"], "#{record["id"]} prohibited_fields")
      end)

    risk_ages = %{
      "internal_read" => 43_200,
      "confidential_read_or_ordinary_command" => 14_400,
      "high_risk_effect" => 600,
      "secret_or_severe_incident" => 300
    }

    errors =
      Enum.reduce(identity["risk_rules"] || [], errors, fn rule, acc ->
        acc
        |> require_equal(
          rule["maximum_authentication_age_seconds"],
          risk_ages[rule["id"]],
          "#{rule["id"]} authentication age"
        )
        |> require_member(
          rule["minimum_assurance"],
          @assurance_levels,
          "#{rule["id"]} minimum assurance"
        )
      end)

    session = identity["session_policy"] || %{}
    compatibility = identity["compatibility_operator"] || %{}

    errors
    |> require_equal(session["hard_lifetime_seconds"], 43_200, "session hard lifetime")
    |> require_equal(session["idle_lifetime_seconds"], 1_800, "session idle lifetime")
    |> require_equal(session["idle_warning_seconds"], 300, "session idle warning")
    |> require_equal(session["sliding_beyond_hard_expiry"], false, "session hard expiry")
    |> require_equal(get_in(session, ["cookie", "secure"]), true, "Secure session cookie")
    |> require_equal(get_in(session, ["cookie", "http_only"]), true, "HTTP-only session cookie")
    |> require_equal(get_in(session, ["cookie", "host_only"]), true, "host-only session cookie")
    |> require_equal(session["tls_required"], true, "TLS requirement")
    |> require_equal(
      compatibility["may_enter_multi_user_routes"],
      false,
      "compatibility operator multi-user route access"
    )
    |> require_equal(
      compatibility["may_delegate_human_authority"],
      false,
      "compatibility operator delegation"
    )
    |> require_equal(
      compatibility["may_satisfy_separation_of_duty"],
      false,
      "compatibility operator separation of duty"
    )
    |> require_git_commit(root, @baseline_commit)
  end

  defp validate_matrix(errors, matrix) do
    operations = matrix["operations"] || []
    role_ids = Enum.map(matrix["roles"] || [], & &1["id"])

    errors =
      errors
      |> require_equal(matrix["schema_version"], 1, "authorization matrix schema_version")
      |> require_equal(
        matrix["baseline_commit"],
        @baseline_commit,
        "authorization matrix baseline"
      )
      |> require_exact_set(role_ids, @roles, "role vocabulary")
      |> require_exact_set(
        get_in(matrix, ["authority_builder", "entry_points"]) || [],
        @surfaces ++ ["controller", "api"],
        "authority builder entry points"
      )
      |> require_exact_set(
        matrix["mandatory_binding_dimensions"] || [],
        @binding_dimensions,
        "mandatory binding dimensions"
      )
      |> require_exact_ids(matrix["outcomes"], @outcomes, "authorization outcome")
      |> require_exact_set(
        matrix["reauthorization_points"] || [],
        @reauthorization_points,
        "reauthorization points"
      )
      |> require_equal(length(operations), 27, "authorization operation count")
      |> require_unique(Enum.map(operations, & &1["id"]), "authorization operation id")
      |> require_exact_set(
        Enum.map(operations, & &1["surface"]) |> Enum.uniq(),
        @surfaces,
        "operation surfaces"
      )

    errors =
      Enum.reduce(matrix["roles"] || [], errors, fn role, acc ->
        acc
        |> require_nonempty(role["navigation"], "#{role["id"]} navigation")
        |> require_equal(role["exact_grants"], [], "#{role["id"]} must not contain grants")
      end)

    Enum.reduce(operations, errors, fn operation, acc ->
      acc =
        acc
        |> require_nonempty(
          operation["role_explanations"],
          "#{operation["id"]} role explanations"
        )
        |> require_subset(
          operation["role_explanations"],
          role_ids,
          "#{operation["id"]} role explanations"
        )
        |> require_nonempty(
          operation["additional_bindings"],
          "#{operation["id"]} additional bindings"
        )
        |> require_nonempty(operation["reauthorize_at"], "#{operation["id"]} reauthorization")
        |> require_subset(
          operation["reauthorize_at"],
          @reauthorization_points,
          "#{operation["id"]} reauthorization"
        )

      validate_binding(acc, operation)
    end)
  end

  defp validate_binding(errors, operation) do
    binding = operation["binding"] || %{}

    cond do
      query = binding["query"] ->
        validate_query_binding(errors, operation["id"], binding, query)

      command = binding["command"] ->
        validate_command_binding(errors, operation["id"], binding, command)

      binding["status"] == "future_contract_only" ->
        capabilities = Enum.map(Authorization.capabilities(), &Atom.to_string/1)

        errors
        |> require_member(
          binding["required_capability"],
          capabilities,
          "#{operation["id"]} future capability"
        )
        |> require_text(binding["owner"], "#{operation["id"]} future owner")
        |> require_text(
          binding["unavailable_reason"],
          "#{operation["id"]} unavailable reason"
        )
        |> require_equal(
          Map.has_key?(binding, "query") or Map.has_key?(binding, "command"),
          false,
          "#{operation["id"]} future binding must not invent a registry entry"
        )

      true ->
        ["#{operation["id"]} is missing a reviewed query, command, or future binding" | errors]
    end
  end

  defp validate_query_binding(errors, id, binding, query) do
    version = query["version"]
    name = query["name"]
    name_atom = Enum.find(QueryCatalog.names(version), &(Atom.to_string(&1) == name))

    case name_atom && QueryCatalog.fetch(name_atom, version) do
      {:ok, definition} ->
        require_equal(
          errors,
          Atom.to_string(definition.capability),
          binding["capability"],
          "#{id} query capability"
        )

      _missing ->
        [
          "#{id} query #{inspect(name)}@#{inspect(version)} is not in the reviewed catalog"
          | errors
        ]
    end
  end

  defp validate_command_binding(errors, id, binding, command) do
    case CommandRegistry.resolve(command["name"], command["version"]) do
      {:ok, definition} ->
        require_equal(
          errors,
          Atom.to_string(definition.capability),
          binding["capability"],
          "#{id} command capability"
        )

      _missing ->
        [
          "#{id} command #{inspect(command["name"])}@#{inspect(command["version"])} is not in the semantic registry"
          | errors
        ]
    end
  end

  defp validate_approval(errors, approval) do
    errors
    |> require_equal(approval["schema_version"], 1, "approval schema_version")
    |> require_equal(approval["baseline_commit"], @baseline_commit, "approval baseline")
    |> require_equal(
      get_in(approval, ["action_digest", "encoding"]),
      "erlang_term_to_binary_deterministic",
      "action digest encoding"
    )
    |> require_equal(
      get_in(approval, ["checker_rules", "distinct_from_maker"]),
      true,
      "maker/checker separation"
    )
    |> require_equal(
      get_in(approval, ["checker_rules", "role_is_eligibility"]),
      false,
      "role eligibility"
    )
    |> require_exact_ids(approval["approval_states"], @approval_states, "approval state")
    |> require_exact_ids(
      approval["approval_transitions"],
      @approval_transitions,
      "approval transition"
    )
    |> require_exact_ids(
      get_in(approval, ["commit_compare_and_set", "outcomes"]),
      @commit_outcomes,
      "commit outcome"
    )
    |> require_equal(
      get_in(approval, ["commit_compare_and_set", "maximum_conflicting_winners"]),
      1,
      "maximum conflicting winners"
    )
    |> require_exact_ids(
      approval["revocation_dimensions"],
      @revocation_dimensions,
      "revocation dimension"
    )
    |> require_equal(
      get_in(approval, ["revocation_event", "next_generation_rule"]),
      "prior_plus_one",
      "revocation generation rule"
    )
    |> require_equal(
      get_in(approval, ["revocation_event", "delivery_path"]),
      "independent_of_projection_hints",
      "revocation delivery path"
    )
    |> require_exact_ids(
      approval["protected_delivery_states"],
      @delivery_states,
      "protected delivery state"
    )
    |> require_exact_set(
      approval["terminal_client_actions"] || [],
      @terminal_client_actions,
      "terminal client actions"
    )
    |> require_equal(
      get_in(approval, ["reauthorization", "revocation_waits_for_periodic_check"]),
      false,
      "revocation periodic-check dependency"
    )
    |> require_equal(
      get_in(approval, ["reauthorization", "revocation_waits_for_projection_hint"]),
      false,
      "revocation projection-hint dependency"
    )
  end

  defp validate_scenarios(errors, matrix, approval, scenarios) do
    authorization = scenarios["authorization_scenarios"] || []
    approval_scenarios = scenarios["approval_scenarios"] || []
    revocation = scenarios["revocation_scenarios"] || []
    all = authorization ++ approval_scenarios ++ revocation
    threat_ids = Enum.map(scenarios["threat_trace"] || [], & &1["id"])

    errors =
      errors
      |> require_equal(scenarios["schema_version"], 1, "scenario schema_version")
      |> require_exact_ids(scenarios["threat_trace"], @threats, "threat trace")
      |> require_unique(Enum.map(all, & &1["id"]), "policy scenario id")
      |> require_nonempty(authorization, "authorization scenarios")
      |> require_nonempty(approval_scenarios, "approval scenarios")
      |> require_nonempty(revocation, "revocation scenarios")

    errors =
      Enum.reduce(all, errors, fn scenario, acc ->
        acc
        |> require_nonempty(scenario["threat_ids"], "#{scenario["id"]} threat_ids")
        |> require_subset(scenario["threat_ids"], threat_ids, "#{scenario["id"]} threat_ids")
        |> require_text(scenario["expected"], "#{scenario["id"]} expected outcome")
      end)

    errors =
      Enum.reduce(authorization, errors, fn scenario, acc ->
        actual =
          evaluate_authorization(
            matrix,
            scenarios["authorization_defaults"],
            scenario
          )

        require_equal(
          acc,
          actual,
          scenario["expected"],
          "#{scenario["id"]} authorization outcome"
        )
      end)

    errors =
      Enum.reduce(approval_scenarios, errors, fn scenario, acc ->
        require_equal(
          acc,
          evaluate_approval(scenario),
          scenario["expected"],
          "#{scenario["id"]} approval outcome"
        )
      end)

    errors =
      Enum.reduce(revocation, errors, fn scenario, acc ->
        require_equal(
          acc,
          evaluate_revocation(approval, scenario),
          scenario["expected"],
          "#{scenario["id"]} revocation outcome"
        )
      end)

    covered = all |> Enum.flat_map(&(&1["threat_ids"] || [])) |> Enum.uniq()
    require_exact_set(errors, covered, @threats, "scenario threat coverage")
  end

  defp validate_documents(errors, root) do
    errors = Enum.reduce(@required_docs, errors, &require_path(&2, root, &1, "HUI-A2 document"))

    errors =
      Enum.reduce(@required_docs, errors, fn path, acc ->
        case File.read(Path.join(root, path)) do
          {:ok, body} -> validate_markdown_links(acc, root, path, body)
          {:error, _reason} -> acc
        end
      end)

    adr =
      read(root, "docs/adr/0009-human-identity-scoped-authorization-and-separation-of-duty.md")

    contract = read(root, "docs/architecture/human-identity-scope-and-authorization-contract.md")
    threat = read(root, "docs/architecture/ui-security-privacy-and-threat-model.md")
    receipt = read(root, "docs/architecture/hypermedia-ui-milestone-a-phase-02-receipt.md")

    plan =
      read(
        root,
        "docs/planning/secure-hypermedia-control-plane-ui/milestone-a-architectural-authority/phase-02-human-identity-and-authorization-authority.md"
      )

    errors =
      errors
      |> require_contains(
        adr,
        "Status: Accepted for architecture authority; implementation and release gated",
        "ADR 0009 accepted status"
      )
      |> require_contains(contract, "Specification version: `1.0.0`", "identity contract version")
      |> require_contains(
        threat,
        "## HUI-A2 Accepted Threat Trace",
        "HUI-A2 threat trace heading"
      )
      |> require_contains(plan, "- [x] 2.1 Section", "Phase 2 Section 2.1 checkbox")
      |> require_contains(plan, "- [x] 2.2 Section", "Phase 2 Section 2.2 checkbox")
      |> require_contains(plan, "- [x] 2.3 Section", "Phase 2 Section 2.3 checkbox")
      |> require_contains(plan, "- [x] 2.4.1 Task", "Phase 2 integration task checkbox")
      |> validate_closure_state(plan, receipt)

    Enum.reduce(@threats, errors, fn threat_id, acc ->
      require_contains(acc, threat, "`#{threat_id}`", "#{threat_id} threat trace")
    end)
  end

  defp validate_closure_state(errors, plan, receipt) do
    if String.contains?(receipt, "Status: **accepted-at-merged-candidate**") do
      errors
      |> require_contains(plan, "status: completed", "Phase 2 completed status")
      |> require_contains(plan, "- [x] 2 Phase", "Phase 2 closure checkbox")
      |> require_contains(
        plan,
        "- [x] 2.4 Section",
        "Phase 2 integration section closure checkbox"
      )
      |> require_contains(plan, "- [x] 2.4.2 Task", "Phase 2 receipt closure checkbox")
      |> require_contains(plan, "- [x] 2.4.2.3 Subtask", "Phase 2 merged-candidate checkbox")
      |> require_contains(receipt, @implementation_commit, "Phase 2 implementation commit")
      |> require_contains(receipt, @merged_candidate, "Phase 2 merged candidate")
      |> require_contains(receipt, @merged_date, "Phase 2 merge date")
    else
      errors
      |> require_contains(plan, "status: proposed", "Phase 2 proposed status")
      |> require_contains(plan, "- [ ] 2 Phase", "Phase 2 closure checkbox")
      |> require_contains(
        plan,
        "- [ ] 2.4 Section",
        "Phase 2 integration section closure checkbox"
      )
      |> require_contains(plan, "- [ ] 2.4.2 Task", "Phase 2 receipt closure checkbox")
      |> require_contains(plan, "- [ ] 2.4.2.3 Subtask", "Phase 2 merged-candidate checkbox")
      |> require_contains(receipt, "Status: **merge-pending**", "Phase 2 merge-pending status")
    end
  end

  defp concealed_failure?(context) do
    context["resource_exists"] != true or
      context["tenant_membership_current"] != true or
      context["project_membership_current"] != true or
      context["exact_grant_current"] != true or
      context["scope_contains"] != true or
      (context["delegation_present"] == true and context["delegation_current"] != true)
  end

  defp decision_stale?(context) do
    context["environment_allowed"] != true or
      context["lifecycle_allowed"] != true or
      context["policy_revision_current"] != true or
      context["graph_revisions_current"] != true or
      context["incident_posture_allowed"] != true or
      (context["fence_applicable"] == true and context["fence_current"] != true)
  end

  defp validate_markdown_links(errors, root, source_path, body) do
    Regex.scan(~r/\[[^\]]+\]\(([^)]+)\)/, body, capture: :all_but_first)
    |> Enum.reduce(errors, fn [target], acc ->
      target = target |> String.split("#", parts: 2) |> hd()

      cond do
        target == "" ->
          acc

        String.starts_with?(target, ["http://", "https://", "mailto:"]) ->
          acc

        true ->
          resolved = Path.expand(target, Path.dirname(Path.join(root, source_path)))

          if File.exists?(resolved),
            do: acc,
            else: ["#{source_path} link target does not exist: #{target}" | acc]
      end
    end)
  end

  defp read(root, path) do
    case File.read(Path.join(root, path)) do
      {:ok, body} -> body
      {:error, _reason} -> ""
    end
  end

  defp require_git_commit(errors, root, commit) do
    case System.cmd("git", ["cat-file", "-e", "#{commit}^{commit}"],
           cd: root,
           stderr_to_stdout: true
         ) do
      {_output, 0} ->
        errors

      {output, _status} ->
        ["cannot resolve HUI-A2 baseline commit: #{String.trim(output)}" | errors]
    end
  end

  defp require_path(errors, root, path, label) do
    if is_binary(path) and File.exists?(Path.join(root, path)),
      do: errors,
      else: ["#{label} does not exist: #{inspect(path)}" | errors]
  end

  defp require_exact_ids(errors, values, expected, label) when is_list(values) do
    require_exact_set(errors, Enum.map(values, & &1["id"]), expected, "#{label} ids")
  end

  defp require_exact_ids(errors, _values, _expected, label),
    do: ["#{label} records are missing" | errors]

  defp require_exact_set(errors, actual, expected, label) when is_list(actual) do
    if MapSet.new(actual) == MapSet.new(expected) and length(actual) == length(Enum.uniq(actual)),
      do: errors,
      else: ["#{label} do not match the accepted set" | errors]
  end

  defp require_exact_set(errors, _actual, _expected, label),
    do: ["#{label} are missing" | errors]

  defp require_unique(errors, values, label) do
    duplicates = values -- Enum.uniq(values)

    if duplicates == [],
      do: errors,
      else: ["duplicate #{label}: #{inspect(Enum.uniq(duplicates))}" | errors]
  end

  defp require_subset(errors, values, allowed, label) when is_list(values) do
    invalid = values -- allowed

    if invalid == [],
      do: errors,
      else: ["#{label} contain unknown values: #{inspect(invalid)}" | errors]
  end

  defp require_subset(errors, _values, _allowed, label), do: ["#{label} are missing" | errors]

  defp require_member(errors, value, allowed, label) do
    if value in allowed, do: errors, else: ["#{label} is invalid: #{inspect(value)}" | errors]
  end

  defp require_nonempty(errors, values, _label) when is_list(values) and values != [], do: errors
  defp require_nonempty(errors, _values, label), do: ["#{label} are missing" | errors]

  defp require_text(errors, value, _label) when is_binary(value) and byte_size(value) > 0,
    do: errors

  defp require_text(errors, _value, label), do: ["#{label} is missing" | errors]

  defp require_contains(errors, body, expected, label) do
    if String.contains?(body, expected), do: errors, else: ["#{label} is missing" | errors]
  end

  defp require_equal(errors, actual, expected, label) do
    if actual == expected,
      do: errors,
      else: ["#{label}: expected #{inspect(expected)}, got #{inspect(actual)}" | errors]
  end
end
