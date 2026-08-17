defmodule JidoCode.Factory.Harness.PhaseH02SubscriptionProfileTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.CredentialReference
  alias JidoCode.Factory.Model.LiveConsent
  alias JidoCode.Factory.Model.Request
  alias JidoCode.Factory.Model.Response
  alias JidoCode.Factory.Model.SubscriptionProfile
  alias JidoCode.Factory.ModelGateway
  alias JidoCode.Integrations.GhTokenProvider
  alias JidoCode.Integrations.OAuthFileEnrollment
  alias JidoCode.Integrations.OAuthFileLease
  alias JidoCode.Integrations.OAuthFileProvider
  alias JidoCode.Integrations.ReqLLM, as: ReqLLMAdapter
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.FakeModelAuthority
  alias JidoCode.TestSupport.FakeReqLLMClient
  alias JidoCode.TestSupport.FakeSecretProvider

  test "pins all subscription paths to ReqLLM 1.20.0 and exact provider contracts" do
    contracts = SubscriptionProfile.contracts()

    assert contracts.openai_codex_oauth == %{
             version: "req_llm-1.20.0/openai-codex-oauth/1",
             provider: "openai_codex",
             model: "gpt-5.3-codex",
             endpoint: "https://chatgpt.com/backend-api",
             sources: [:explicit_access_token, :oauth_file]
           }

    assert contracts.anthropic_subscription.model == "claude-sonnet-4-5-20250929"
    assert contracts.anthropic_subscription.endpoint == "https://api.anthropic.com"
    assert contracts.github_copilot.model == "gpt-4o-mini"
    assert contracts.github_copilot.endpoint == "https://api.githubcopilot.com"

    for {_name, contract} <- contracts do
      assert {:ok, %LLMDB.Model{catalog_only: false, deprecated: false, retired: false}} =
               ReqLLM.model(contract.provider <> ":" <> contract.model)
    end
  end

  test "requires provider-terms evidence and consented live verification before enrollment" do
    reference = credential_reference(:openai_codex_oauth, :explicit_access_token)
    attributes = profile_attributes(:openai_codex_oauth, :explicit_access_token)

    assert {:error, %AdapterError{operation: :subscription_profile}} =
             attributes
             |> Map.put(:terms_status, :required)
             |> SubscriptionProfile.new(reference)

    assert {:error, %AdapterError{operation: :subscription_profile}} =
             attributes
             |> Map.put(:live_status, :consent_pending)
             |> SubscriptionProfile.new(reference)

    previous = System.get_env("JIDO_CODE_LIVE_SUBSCRIPTION_TESTS")
    on_exit(fn -> restore_env("JIDO_CODE_LIVE_SUBSCRIPTION_TESTS", previous) end)
    System.delete_env("JIDO_CODE_LIVE_SUBSCRIPTION_TESTS")

    assert {:error, %AdapterError{operation: :live_subscription_test}} =
             LiveConsent.authorize(consent: :granted, live_test: true)

    System.put_env("JIDO_CODE_LIVE_SUBSCRIPTION_TESTS", "1")

    assert {:error, %AdapterError{operation: :live_subscription_test}} =
             LiveConsent.authorize(consent: :denied, live_test: true)

    assert {:error, %AdapterError{operation: :live_subscription_test}} =
             LiveConsent.authorize(consent: :granted, live_test: false)

    assert :ok = LiveConsent.authorize(consent: :granted, live_test: true)
  end

  test "passes an explicit short-lived token per call without ambient fallback" do
    reference = credential_reference(:openai_codex_oauth, :explicit_access_token)
    assert {:ok, profile} = subscription_profile(:openai_codex_oauth, reference)
    FakeReqLLMClient.put_generate_result({:ok, req_llm_response(profile.model)})

    secret_provider =
      {FakeSecretProvider, %{owner: self(), result: {:ok, "short-lived-access-token"}}}

    assert {:ok, %Response{provenance: provenance}} =
             ModelGateway.generate(gateway(profile, secret_provider), request(profile))

    assert_received {:req_llm_generate_text, "openai_codex:gpt-5.3-codex", _messages, options}

    assert Keyword.fetch!(options, :access_token) == "short-lived-access-token"
    assert Keyword.fetch!(options, :auth_mode) == :oauth

    assert Keyword.fetch!(options, :provider_options) ==
             [store: false, openai_reuse_websocket: false, openai_stream_transport: :sse]

    refute Keyword.has_key?(options, :api_key)
    refute Keyword.has_key?(options, :previous_response_id)
    refute Keyword.has_key?(options, :openai_websocket_session)
    assert provenance.recovery_mode == :new_interaction_from_graph
  end

  test "rejects expired or long-lived explicit token enrollment" do
    reference = credential_reference(:openai_codex_oauth, :explicit_access_token)
    attributes = profile_attributes(:openai_codex_oauth, :explicit_access_token)

    assert {:error, %AdapterError{operation: :subscription_profile}} =
             attributes
             |> Map.put(:credential_expires_at, DateTime.add(DateTime.utc_now(), -1, :second))
             |> SubscriptionProfile.new(reference)

    assert {:error, %AdapterError{operation: :subscription_profile}} =
             attributes
             |> Map.put(:credential_expires_at, DateTime.add(DateTime.utc_now(), 7_200, :second))
             |> SubscriptionProfile.new(reference)
  end

  test "wraps gh auth token locally and forces ReqLLM token mode" do
    reference = credential_reference(:github_copilot, :gh_auth_token)
    assert {:ok, profile} = subscription_profile(:github_copilot, reference)
    FakeReqLLMClient.put_generate_result({:ok, req_llm_response(profile.model)})

    owner = self()

    runner = fn ->
      send(owner, :gh_auth_token_invoked)
      {"github-cli-token\n", 0}
    end

    assert {:ok, provider} = GhTokenProvider.new(runner: runner)

    assert {:ok, %Response{}} =
             ModelGateway.generate(
               gateway(profile, {GhTokenProvider, provider}),
               request(profile)
             )

    assert_received :gh_auth_token_invoked
    assert_received {:req_llm_generate_text, "github_copilot:gpt-4o-mini", _messages, options}
    assert Keyword.fetch!(options, :api_key) == "github-cli-token"
    assert Keyword.fetch!(options, :github_copilot_auth) == :token
    assert Keyword.fetch!(options, :provider_options) == []

    assert {:error, %AdapterError{operation: :subscription_profile}} =
             :github_copilot
             |> profile_attributes(:gh_auth_token)
             |> Map.put(:deployment, :managed)
             |> SubscriptionProfile.new(reference)
  end

  test "enrolls only absolute, regular, owner-matched, private files outside protected roots" do
    fixture = oauth_fixture()

    assert {:ok, reference} =
             OAuthFileEnrollment.enroll(fixture.attributes,
               forbidden_roots: fixture.forbidden_roots
             )

    refute inspect(reference) =~ fixture.path

    assert {:error, %AdapterError{operation: :oauth_file_enrollment}} =
             OAuthFileEnrollment.enroll(
               %{fixture.attributes | expected_uid: fixture.attributes.expected_uid + 1},
               forbidden_roots: fixture.forbidden_roots
             )

    File.chmod!(fixture.path, 0o644)

    assert {:error, %AdapterError{operation: :oauth_file_enrollment}} =
             OAuthFileEnrollment.enroll(fixture.attributes,
               forbidden_roots: fixture.forbidden_roots
             )

    File.chmod!(fixture.path, 0o600)

    assert {:error, %AdapterError{operation: :oauth_file_enrollment}} =
             OAuthFileEnrollment.enroll(fixture.attributes,
               forbidden_roots: [fixture.root]
             )

    symlink = Path.join(fixture.root, "oauth-link.json")
    File.ln_s!(fixture.path, symlink)

    assert {:error, %AdapterError{operation: :oauth_file_enrollment}} =
             OAuthFileEnrollment.enroll(%{fixture.attributes | path: symlink},
               forbidden_roots: fixture.forbidden_roots
             )

    real_directory = Path.join(fixture.root, "real-oauth")
    File.mkdir_p!(real_directory)
    nested_path = Path.join(real_directory, "oauth.json")
    File.write!(nested_path, ~s({"fixture":"not-a-real-credential"}))
    File.chmod!(nested_path, 0o600)
    directory_link = Path.join(fixture.root, "oauth-directory-link")
    File.ln_s!(real_directory, directory_link)

    assert {:error, %AdapterError{operation: :oauth_file_enrollment}} =
             OAuthFileEnrollment.enroll(
               %{fixture.attributes | path: Path.join(directory_link, "oauth.json")},
               forbidden_roots: fixture.forbidden_roots
             )
  end

  test "revalidates an enrolled OAuth file on every credential release" do
    fixture = oauth_fixture()

    assert {:ok, reference} =
             OAuthFileEnrollment.enroll(fixture.attributes,
               forbidden_roots: fixture.forbidden_roots
             )

    assert {:ok, provider} =
             OAuthFileProvider.new(%{"oauth-file" => reference}, fixture.forbidden_roots)

    credential = credential_reference(:openai_codex_oauth, :oauth_file)
    path = fixture.path
    assert {:ok, ^path} = OAuthFileProvider.fetch(provider, credential)

    File.chmod!(fixture.path, 0o644)

    assert {:error, %AdapterError{operation: :oauth_file_enrollment}} =
             OAuthFileProvider.fetch(provider, credential)
  end

  test "allows OAuth-file refresh only for developer-local exclusive ReqLLM ownership" do
    fixture = oauth_fixture()

    assert {:ok, oauth_reference} =
             OAuthFileEnrollment.enroll(fixture.attributes,
               forbidden_roots: fixture.forbidden_roots
             )

    credential = credential_reference(:openai_codex_oauth, :oauth_file)

    assert {:error, %AdapterError{operation: :subscription_profile}} =
             :openai_codex_oauth
             |> profile_attributes(:oauth_file)
             |> Map.put(:deployment, :managed)
             |> SubscriptionProfile.new(credential, oauth_file_reference: oauth_reference)

    assert {:error, %AdapterError{operation: :subscription_profile}} =
             :openai_codex_oauth
             |> profile_attributes(:oauth_file)
             |> Map.put(:refresh_owner, :provider_cli)
             |> SubscriptionProfile.new(credential, oauth_file_reference: oauth_reference)

    assert {:ok, profile} =
             subscription_profile(:openai_codex_oauth, credential,
               oauth_file_reference: oauth_reference
             )

    assert profile.deployment == :developer_local
    assert profile.refresh_owner == :req_llm
  end

  test "dispatches only the explicitly enrolled OAuth path under the refresh lease" do
    fixture = oauth_fixture()

    assert {:ok, oauth_reference} =
             OAuthFileEnrollment.enroll(fixture.attributes,
               forbidden_roots: fixture.forbidden_roots
             )

    credential = credential_reference(:openai_codex_oauth, :oauth_file)

    assert {:ok, profile} =
             subscription_profile(:openai_codex_oauth, credential,
               oauth_file_reference: oauth_reference
             )

    assert {:ok, provider} =
             OAuthFileProvider.new(%{"oauth-file" => oauth_reference}, fixture.forbidden_roots)

    FakeReqLLMClient.put_generate_result({:ok, req_llm_response(profile.model)})

    assert {:ok, %Response{}} =
             ModelGateway.generate(
               gateway(profile, {OAuthFileProvider, provider}),
               request(profile)
             )

    assert_received {:req_llm_generate_text, "openai_codex:gpt-5.3-codex", _messages, options}

    assert Keyword.fetch!(options, :oauth_file) == fixture.path
    assert Keyword.fetch!(options, :auth_mode) == :oauth
    refute Keyword.has_key?(options, :access_token)
    refute Keyword.has_key?(options, :auth_file)
  end

  test "serializes OAuth refresh ownership and rejects a concurrent profile call" do
    fixture = oauth_fixture()

    assert {:ok, reference} =
             OAuthFileEnrollment.enroll(fixture.attributes,
               forbidden_roots: fixture.forbidden_roots
             )

    owner = self()

    holder =
      Task.async(fn ->
        OAuthFileLease.with_lock(reference, fn ->
          send(owner, :oauth_refresh_locked)

          receive do
            :release_oauth_refresh -> :released
          end
        end)
      end)

    assert_receive :oauth_refresh_locked

    assert {:error, %AdapterError{kind: :conflict, operation: :oauth_file_refresh_lock}} =
             OAuthFileLease.with_lock(reference, fn -> flunk("concurrent refresh ran") end)

    send(holder.pid, :release_oauth_refresh)
    assert Task.await(holder) == :released
  end

  test "provider response IDs remain external references and cannot seed recovery options" do
    reference = credential_reference(:anthropic_subscription, :explicit_access_token)
    assert {:ok, profile} = subscription_profile(:anthropic_subscription, reference)
    FakeReqLLMClient.put_generate_result({:ok, req_llm_response(profile.model)})

    secret_provider = {FakeSecretProvider, %{owner: self(), result: {:ok, "anthropic-token"}}}

    assert {:ok, %Response{call_metadata: %{response_id: "response-external"}} = response} =
             ModelGateway.generate(gateway(profile, secret_provider), request(profile))

    assert response.provenance.recovery_mode == :new_interaction_from_graph

    assert_received {:req_llm_generate_text, _model, _messages, options}
    refute Keyword.has_key?(options, :previous_response_id)
    refute Keyword.has_key?(options, :conversation_id)
  end

  defp subscription_profile(contract, reference, options \\ []) do
    source = source_from_reference(reference, options)

    SubscriptionProfile.new(
      profile_attributes(contract, source),
      reference,
      options
    )
  end

  defp source_from_reference(%CredentialReference{key: "gh-auth-token"}, _options),
    do: :gh_auth_token

  defp source_from_reference(_reference, options) do
    if Keyword.has_key?(options, :oauth_file_reference),
      do: :oauth_file,
      else: :explicit_access_token
  end

  defp profile_attributes(contract, source) do
    pin = Map.fetch!(SubscriptionProfile.contracts(), contract)

    %{
      profile_iri: deterministic!(:model_access_profile, "subscription-#{contract}-#{source}"),
      contract: contract,
      provider: pin.provider,
      model: pin.model,
      endpoint: pin.endpoint,
      access_mode: :host_subscription,
      credential_class: :short_lived_bearer,
      billing_mode: :subscription,
      credential_source: source,
      credential_expires_at:
        if(source == :explicit_access_token,
          do: DateTime.add(DateTime.utc_now(), 3_600, :second),
          else: nil
        ),
      credential_reference_iri:
        deterministic!(:knowledge_assertion, "subscription-credential-#{contract}-#{source}"),
      deployment: :developer_local,
      refresh_owner: if(source == :oauth_file, do: :req_llm, else: :host_adapter),
      terms_status: :accepted,
      terms_evidence_iri: deterministic!(:evidence_claim, "terms-#{contract}"),
      live_status: :verified,
      live_verification_iri: deterministic!(:verification_activity, "live-#{contract}")
    }
  end

  defp credential_reference(contract, source) do
    pin = Map.fetch!(SubscriptionProfile.contracts(), contract)

    key =
      case source do
        :gh_auth_token -> "gh-auth-token"
        :oauth_file -> "oauth-file"
        :explicit_access_token -> "short-lived-token"
      end

    {:ok, reference} =
      CredentialReference.new(%{
        iri:
          deterministic!(:knowledge_assertion, "subscription-credential-#{contract}-#{source}"),
        provider: pin.provider,
        key: key
      })

    reference
  end

  defp request(profile) do
    {:ok, request} =
      Request.new(%{
        invocation_iri:
          deterministic!(:model_invocation, "subscription-invocation-#{profile.contract}"),
        profile_iri: profile.profile_iri,
        context_manifest_iri:
          deterministic!(:context_manifest, "subscription-context-#{profile.contract}"),
        provider: profile.provider,
        model: profile.model,
        messages: "compiled context",
        options: [max_tokens: 256],
        deadline: DateTime.add(DateTime.utc_now(), 30, :second)
      })

    request
  end

  defp gateway(profile, secret_provider) do
    assert {:ok, adapter} = ReqLLMAdapter.new(client: FakeReqLLMClient)

    assert {:ok, gateway} =
             ModelGateway.new(ReqLLMAdapter, adapter,
               profile: profile,
               secret_provider: secret_provider,
               authority: {FakeModelAuthority, %{owner: self(), results: %{}}}
             )

    gateway
  end

  defp req_llm_response(model) do
    content = ReqLLM.Message.ContentPart.text("subscription answer")
    message = struct(ReqLLM.Message, role: :assistant, content: [content])

    struct(ReqLLM.Response,
      id: "response-external",
      model: model,
      context: [],
      message: message,
      finish_reason: :stop,
      usage: %{input_tokens: 10, output_tokens: 4}
    )
  end

  defp oauth_fixture do
    root =
      Path.join(
        System.tmp_dir!(),
        "jido-code-oauth-#{System.unique_integer([:positive, :monotonic])}"
      )

    File.mkdir_p!(root)
    path = Path.join(root, "oauth.json")
    File.write!(path, ~s({"fixture":"not-a-real-credential"}))
    File.chmod!(path, 0o600)
    uid = File.lstat!(path).uid

    on_exit(fn ->
      File.rm(Path.join(root, "oauth-link.json"))
      File.rm(Path.join(root, "oauth-directory-link"))
      File.rm(Path.join([root, "real-oauth", "oauth.json"]))
      File.rmdir(Path.join(root, "real-oauth"))
      File.rm(path)
      File.rmdir(root)
    end)

    %{
      root: root,
      path: path,
      forbidden_roots: protected_roots(),
      attributes: %{
        iri: deterministic!(:knowledge_assertion, "oauth-file-#{root}"),
        provider: "openai_codex",
        path: path,
        expected_uid: uid,
        refresh_owner: :req_llm,
        deployment: :developer_local
      }
    }
  end

  defp protected_roots do
    root = File.cwd!()

    [
      root,
      Path.join(root, "var/knowledge"),
      Path.join(root, "tmp/sandboxes")
    ]
    |> Enum.map(&Path.expand/1)
  end

  defp deterministic!(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp restore_env(name, nil), do: System.delete_env(name)
  defp restore_env(name, value), do: System.put_env(name, value)
end
