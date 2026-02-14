defmodule JidoCode.Accounts.ApiKey do
  use Ash.Resource,
    otp_app: :jido_code,
    domain: JidoCode.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "api_keys"
    repo JidoCode.Repo
  end

  code_interface do
    define :create
    define :read
    define :get_by_id, action: :read, get_by: [:id]
    define :revoke
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:user_id, :expires_at]

      change {AshAuthentication.Strategy.ApiKey.GenerateApiKey, prefix: :agentjido, hash: :api_key_hash}
    end

    update :revoke do
      accept []
      require_atomic? false

      change fn changeset, _context ->
        case Ash.Changeset.get_data(changeset, :revoked_at) do
          nil ->
            Ash.Changeset.force_change_attribute(
              changeset,
              :revoked_at,
              DateTime.utc_now() |> DateTime.truncate(:microsecond)
            )

          _revoked_at ->
            Ash.Changeset.add_error(
              changeset,
              field: :revoked_at,
              message: "api key has already been revoked",
              vars: [type: "api_key_already_revoked"]
            )
        end
      end
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :api_key_hash, :binary do
      allow_nil? false
      sensitive? true
    end

    attribute :expires_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :revoked_at, :utc_datetime_usec do
      allow_nil? true
      public? true
    end
  end

  relationships do
    belongs_to :user, JidoCode.Accounts.User
  end

  calculations do
    calculate :valid, :boolean, expr(is_nil(revoked_at) and expires_at > now())
  end

  identities do
    identity :unique_api_key, [:api_key_hash]
  end
end
