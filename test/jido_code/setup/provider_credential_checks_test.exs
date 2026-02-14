defmodule JidoCode.Setup.ProviderCredentialChecksTest do
  use ExUnit.Case, async: true

  alias JidoCode.Setup.ProviderCredentialChecks

  @checked_at ~U[2026-02-13 12:34:56Z]
  @previous_checked_at ~U[2026-02-12 08:00:00Z]

  setup do
    original_checker =
      Application.get_env(:jido_code, :setup_provider_credential_checker, :__missing__)

    on_exit(fn ->
      restore_env(:setup_provider_credential_checker, original_checker)
    end)

    :ok
  end

  test "run/1 allows progression when at least one provider is active" do
    Application.put_env(:jido_code, :setup_provider_credential_checker, fn _context ->
      %{
        checked_at: @checked_at,
        status: :active,
        credentials: [
          %{
            provider: :anthropic,
            name: "Anthropic",
            status: :active,
            detail: "ANTHROPIC_API_KEY is configured and passed verification checks.",
            remediation: "Credential is active.",
            verified_at: @checked_at,
            checked_at: @checked_at
          },
          %{
            provider: :openai,
            name: "OpenAI",
            status: :invalid,
            detail: "Configured OPENAI_API_KEY failed verification checks.",
            remediation: "Set a valid `OPENAI_API_KEY` (typically prefixed with `sk-`) and retry verification.",
            checked_at: @checked_at
          }
        ]
      }
    end)

    report = ProviderCredentialChecks.run(nil)

    refute ProviderCredentialChecks.blocked?(report)

    anthropic = Enum.find(report.credentials, fn credential -> credential.provider == :anthropic end)
    openai = Enum.find(report.credentials, fn credential -> credential.provider == :openai end)

    assert anthropic.status == :active
    assert anthropic.transition == "Not set -> Active"
    assert %DateTime{} = anthropic.verified_at

    assert openai.status == :invalid
    assert openai.transition == "Not set -> Invalid"
    assert openai.remediation =~ "OPENAI_API_KEY"
  end

  test "run/1 blocks progression when all provider checks fail" do
    Application.put_env(:jido_code, :setup_provider_credential_checker, fn _context ->
      %{
        checked_at: @checked_at,
        status: :invalid,
        credentials: [
          %{
            provider: :anthropic,
            name: "Anthropic",
            status: :not_set,
            detail: "No ANTHROPIC_API_KEY credential is configured.",
            remediation: "Set `ANTHROPIC_API_KEY` and retry verification.",
            checked_at: @checked_at
          },
          %{
            provider: :openai,
            name: "OpenAI",
            status: :invalid,
            detail: "Configured OPENAI_API_KEY failed verification checks.",
            remediation: "Set a valid `OPENAI_API_KEY` (typically prefixed with `sk-`) and retry verification.",
            checked_at: @checked_at
          }
        ]
      }
    end)

    report = ProviderCredentialChecks.run(nil)

    assert ProviderCredentialChecks.blocked?(report)

    blocked_providers =
      report
      |> ProviderCredentialChecks.blocked_credentials()
      |> Enum.map(fn credential -> credential.provider end)

    assert :anthropic in blocked_providers
    assert :openai in blocked_providers
  end

  test "serialize_for_state/1 preserves status and verified_at for active credentials" do
    Application.put_env(:jido_code, :setup_provider_credential_checker, fn _context ->
      %{
        checked_at: @checked_at,
        status: :active,
        credentials: [
          %{
            provider: :anthropic,
            name: "Anthropic",
            status: :active,
            detail: "ANTHROPIC_API_KEY is configured and passed verification checks.",
            remediation: "Credential is active.",
            verified_at: @checked_at,
            checked_at: @checked_at
          }
        ]
      }
    end)

    report = ProviderCredentialChecks.run(nil)
    serialized = ProviderCredentialChecks.serialize_for_state(report)
    restored = ProviderCredentialChecks.from_state(serialized)

    assert serialized["status"] == "active"

    [restored_credential] = restored.credentials
    assert restored_credential.status == :active
    assert %DateTime{} = restored_credential.verified_at
  end

  test "run/1 updates verified_at for successful checks and preserves prior timestamp on failed checks" do
    Application.put_env(:jido_code, :setup_provider_credential_checker, fn _context ->
      %{
        checked_at: @checked_at,
        status: :active,
        credentials: [
          %{
            provider: :anthropic,
            name: "Anthropic",
            status: :active,
            detail: "ANTHROPIC_API_KEY is configured and passed verification checks.",
            remediation: "Credential is active.",
            checked_at: @checked_at
          },
          %{
            provider: :openai,
            name: "OpenAI",
            status: :invalid,
            detail: "Configured OPENAI_API_KEY failed verification checks.",
            remediation: "Set a valid `OPENAI_API_KEY` (typically prefixed with `sk-`) and retry verification.",
            checked_at: @checked_at
          }
        ]
      }
    end)

    report =
      previous_provider_state()
      |> ProviderCredentialChecks.run()

    anthropic = Enum.find(report.credentials, fn credential -> credential.provider == :anthropic end)
    openai = Enum.find(report.credentials, fn credential -> credential.provider == :openai end)

    assert anthropic.transition == "Active -> Active"
    assert anthropic.verified_at == @checked_at
    assert openai.transition == "Active -> Invalid"
    assert openai.verified_at == @previous_checked_at
  end

  test "run/1 accepts rotating status transitions" do
    Application.put_env(:jido_code, :setup_provider_credential_checker, fn _context ->
      %{
        checked_at: @checked_at,
        status: :rotating,
        credentials: [
          %{
            provider: :anthropic,
            name: "Anthropic",
            status: :not_set,
            detail: "No ANTHROPIC_API_KEY credential is configured.",
            remediation: "Set `ANTHROPIC_API_KEY` and retry verification.",
            checked_at: @checked_at
          },
          %{
            provider: :openai,
            name: "OpenAI",
            status: :rotating,
            detail: "OPENAI_API_KEY rotation is in progress.",
            remediation: "Complete key rotation and re-run checks.",
            checked_at: @checked_at
          }
        ]
      }
    end)

    report =
      previous_provider_state()
      |> ProviderCredentialChecks.run()

    openai = Enum.find(report.credentials, fn credential -> credential.provider == :openai end)

    assert openai.status == :rotating
    assert openai.transition == "Active -> Rotating"
    assert openai.verified_at == @previous_checked_at
    assert openai.error_type == "openai_credentials_rotating"
  end

  test "run/1 marks checker endpoint errors invalid with typed provider failure details" do
    Application.put_env(:jido_code, :setup_provider_credential_checker, fn _context ->
      {:error, :provider_timeout}
    end)

    report =
      previous_provider_state()
      |> ProviderCredentialChecks.run()

    assert report.status == :invalid

    anthropic = Enum.find(report.credentials, fn credential -> credential.provider == :anthropic end)
    openai = Enum.find(report.credentials, fn credential -> credential.provider == :openai end)

    assert anthropic.status == :invalid
    assert anthropic.transition == "Active -> Invalid"
    assert anthropic.error_type == "anthropic_provider_check_failed"
    assert anthropic.detail =~ "anthropic_provider_check_failed"
    assert anthropic.verified_at == @previous_checked_at

    assert openai.status == :invalid
    assert openai.transition == "Active -> Invalid"
    assert openai.error_type == "openai_provider_check_failed"
    assert openai.detail =~ "openai_provider_check_failed"
    assert openai.verified_at == @previous_checked_at
  end

  defp previous_provider_state do
    %{
      "checked_at" => DateTime.to_iso8601(@previous_checked_at),
      "status" => "active",
      "credentials" => [
        %{
          "provider" => "anthropic",
          "status" => "active",
          "verified_at" => DateTime.to_iso8601(@previous_checked_at),
          "checked_at" => DateTime.to_iso8601(@previous_checked_at)
        },
        %{
          "provider" => "openai",
          "status" => "active",
          "verified_at" => DateTime.to_iso8601(@previous_checked_at),
          "checked_at" => DateTime.to_iso8601(@previous_checked_at)
        }
      ]
    }
  end

  defp restore_env(key, :__missing__), do: Application.delete_env(:jido_code, key)
  defp restore_env(key, value), do: Application.put_env(:jido_code, key, value)
end
