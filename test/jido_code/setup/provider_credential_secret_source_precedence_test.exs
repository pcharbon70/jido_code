defmodule JidoCode.Setup.ProviderCredentialSecretSourcePrecedenceTest do
  use JidoCode.DataCase, async: false

  alias JidoCode.Security.SecretRefs
  alias JidoCode.Setup.ProviderCredentialChecks

  @checked_at ~U[2026-02-14 12:00:00Z]

  setup do
    original_anthropic_env = fetch_system_env("ANTHROPIC_API_KEY")
    original_openai_env = fetch_system_env("OPENAI_API_KEY")
    original_anthropic_app_env = Application.get_env(:jido_code, :anthropic_api_key, :__missing__)
    original_openai_app_env = Application.get_env(:jido_code, :openai_api_key, :__missing__)

    on_exit(fn ->
      restore_system_env("ANTHROPIC_API_KEY", original_anthropic_env)
      restore_system_env("OPENAI_API_KEY", original_openai_env)
      restore_app_env(:anthropic_api_key, original_anthropic_app_env)
      restore_app_env(:openai_api_key, original_openai_app_env)
    end)

    System.delete_env("ANTHROPIC_API_KEY")
    System.delete_env("OPENAI_API_KEY")
    Application.delete_env(:jido_code, :anthropic_api_key)
    Application.delete_env(:jido_code, :openai_api_key)

    :ok
  end

  test "default checker prefers env root secrets over encrypted secret refs and surfaces non-sensitive diagnostics" do
    env_secret = "sk-ant-env-#{System.unique_integer([:positive])}"
    db_secret = "sk-ant-db-#{System.unique_integer([:positive])}"

    assert {:ok, _metadata} =
             SecretRefs.persist_operational_secret(%{
               scope: :integration,
               name: SecretRefs.provider_secret_ref_name(:anthropic),
               value: db_secret,
               source: :onboarding
             })

    System.put_env("ANTHROPIC_API_KEY", env_secret)

    credentials = default_checker_credentials()
    anthropic = Enum.find(credentials, fn credential -> credential.provider == :anthropic end)

    assert anthropic.status == :active
    assert anthropic.detail =~ "source=env"
    assert anthropic.detail =~ "outcome=resolved"
    assert anthropic.detail =~ "env_var=ANTHROPIC_API_KEY"
    assert anthropic.detail =~ "secret_ref_name=providers/anthropic_api_key"
    refute anthropic.detail =~ env_secret
    refute anthropic.detail =~ db_secret
  end

  test "default checker resolves from encrypted secret refs when env root secrets are absent" do
    db_secret = "sk-db-#{System.unique_integer([:positive])}"

    assert {:ok, _metadata} =
             SecretRefs.persist_operational_secret(%{
               scope: :integration,
               name: SecretRefs.provider_secret_ref_name(:openai),
               value: db_secret,
               source: :onboarding
             })

    credentials = default_checker_credentials()
    openai = Enum.find(credentials, fn credential -> credential.provider == :openai end)

    assert openai.status == :active
    assert openai.detail =~ "source=secret_ref"
    assert openai.detail =~ "outcome=resolved"
    assert openai.detail =~ "secret_ref_name=providers/openai_api_key"
    assert openai.detail =~ "secret_ref_key_version=1"
    assert openai.detail =~ "secret_ref_source=onboarding"
    refute openai.detail =~ db_secret
  end

  test "default checker emits typed secret unavailable errors when env and encrypted refs are both missing" do
    credentials = default_checker_credentials()
    report = %{checked_at: @checked_at, status: :not_set, credentials: credentials}

    anthropic = Enum.find(credentials, fn credential -> credential.provider == :anthropic end)
    openai = Enum.find(credentials, fn credential -> credential.provider == :openai end)

    assert anthropic.status == :not_set
    assert anthropic.error_type == "anthropic_secret_unavailable"
    assert anthropic.detail =~ "source=unavailable"
    assert anthropic.detail =~ "outcome=missing"

    assert openai.status == :not_set
    assert openai.error_type == "openai_secret_unavailable"
    assert openai.detail =~ "source=unavailable"
    assert openai.detail =~ "outcome=missing"

    assert ProviderCredentialChecks.blocked?(report)

    blocked_error_types =
      report
      |> ProviderCredentialChecks.blocked_credentials()
      |> Enum.map(fn credential -> credential.error_type end)

    assert "anthropic_secret_unavailable" in blocked_error_types
    assert "openai_secret_unavailable" in blocked_error_types
  end

  defp default_checker_credentials do
    ProviderCredentialChecks.default_checker(%{
      checked_at: @checked_at,
      previous_statuses: %{},
      previous_verified_ats: %{}
    })
  end

  defp restore_app_env(key, :__missing__), do: Application.delete_env(:jido_code, key)
  defp restore_app_env(key, value), do: Application.put_env(:jido_code, key, value)

  defp fetch_system_env(key) do
    case System.get_env(key) do
      nil -> :__missing__
      value -> value
    end
  end

  defp restore_system_env(key, :__missing__), do: System.delete_env(key)
  defp restore_system_env(key, value), do: System.put_env(key, value)
end
