defmodule JidoCode.GitHub.RepoPlaintextSecretPolicyTest do
  use JidoCode.DataCase, async: false

  import ExUnit.CaptureLog

  require Ash.Query

  alias JidoCode.GitHub
  alias JidoCode.GitHub.Repo, as: GitHubRepo

  @plaintext_secret_error_type "plaintext_secret_persistence_blocked"
  @plaintext_secret_policy "operational_secret_plaintext_forbidden"

  test "create rejects plaintext webhook_secret writes with typed policy details and actor audit context" do
    unique_suffix = System.unique_integer([:positive])
    owner = "policy-owner-#{unique_suffix}"
    name = "policy-repo-#{unique_suffix}"
    full_name = "#{owner}/#{name}"
    actor = %{id: "actor-#{unique_suffix}", email: "actor-#{unique_suffix}@example.com"}

    log =
      capture_log(fn ->
        assert {:error, %Ash.Error.Invalid{} = error} =
                 GitHubRepo.create(
                   %{
                     owner: owner,
                     name: name,
                     webhook_secret: "plaintext-secret-#{unique_suffix}"
                   },
                   actor: actor,
                   authorize?: false
                 )

        assert_policy_violation_details(error)
      end)

    assert log =~ "security_audit=blocked_plaintext_secret_persistence"
    assert log =~ "actor_id=#{actor.id}"
    assert log =~ "actor_email=#{actor.email}"

    query =
      GitHubRepo
      |> Ash.Query.filter(full_name == ^full_name)
      |> Ash.Query.limit(1)

    assert {:ok, []} = Ash.read(query, domain: GitHub, authorize?: false)
  end

  test "update rejection is atomic and does not apply fallback plaintext storage or partial updates" do
    unique_suffix = System.unique_integer([:positive])

    assert {:ok, repo} =
             GitHubRepo.create(
               %{
                 owner: "atomic-owner-#{unique_suffix}",
                 name: "atomic-repo-#{unique_suffix}",
                 settings: %{"baseline" => %{"status" => "ready"}}
               },
               authorize?: false
             )

    assert {:error, %Ash.Error.Invalid{} = error} =
             GitHubRepo.update(
               repo,
               %{
                 webhook_secret: "unsafe-plaintext-secret",
                 settings: %{"baseline" => %{"status" => "unsafe"}}
               },
               authorize?: false
             )

    assert_policy_violation_details(error)

    query =
      GitHubRepo
      |> Ash.Query.filter(id == ^repo.id)
      |> Ash.Query.limit(1)

    assert {:ok, [reloaded_repo]} = Ash.read(query, domain: GitHub, authorize?: false)
    assert reloaded_repo.settings == %{"baseline" => %{"status" => "ready"}}
    refute reloaded_repo.webhook_secret == "unsafe-plaintext-secret"
  end

  defp assert_policy_violation_details(%Ash.Error.Invalid{errors: errors}) do
    policy_error =
      Enum.find(errors, fn
        %{vars: vars} when is_list(vars) ->
          Keyword.get(vars, :type) == @plaintext_secret_error_type

        _other ->
          false
      end)

    assert policy_error
    assert %{field: :webhook_secret} = policy_error
    assert policy_error.message =~ "plaintext webhook secret persistence is forbidden"
    assert Keyword.get(policy_error.vars, :error_type) == @plaintext_secret_error_type
    assert Keyword.get(policy_error.vars, :policy) == @plaintext_secret_policy
    assert Keyword.get(policy_error.vars, :remediation) =~ "SecretRef"
  end
end
