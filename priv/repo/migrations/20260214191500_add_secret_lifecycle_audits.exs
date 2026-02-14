defmodule JidoCode.Repo.Migrations.AddSecretLifecycleAudits do
  use Ecto.Migration

  def up do
    create table(:secret_lifecycle_audits, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :secret_ref_id, :uuid, null: false
      add :scope, :text, null: false
      add :name, :text, null: false
      add :action_type, :text, null: false
      add :outcome_status, :text, null: false, default: "succeeded"
      add :actor_id, :text, null: false
      add :actor_email, :text
      add :occurred_at, :utc_datetime_usec, null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:secret_lifecycle_audits, [:secret_ref_id],
             name: "secret_lifecycle_audits_secret_ref_id_index"
           )

    create index(:secret_lifecycle_audits, [:scope, :name, :occurred_at],
             name: "secret_lifecycle_audits_scope_name_occurred_at_index"
           )
  end

  def down do
    drop_if_exists index(:secret_lifecycle_audits, [:scope, :name, :occurred_at],
                     name: "secret_lifecycle_audits_scope_name_occurred_at_index"
                   )

    drop_if_exists index(:secret_lifecycle_audits, [:secret_ref_id],
                     name: "secret_lifecycle_audits_secret_ref_id_index"
                   )

    drop table(:secret_lifecycle_audits)
  end
end
