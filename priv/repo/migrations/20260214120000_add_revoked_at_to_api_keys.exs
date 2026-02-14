defmodule JidoCode.Repo.Migrations.AddRevokedAtToApiKeys do
  use Ecto.Migration

  def up do
    alter table(:api_keys) do
      add :revoked_at, :utc_datetime_usec
    end
  end

  def down do
    alter table(:api_keys) do
      remove :revoked_at
    end
  end
end
