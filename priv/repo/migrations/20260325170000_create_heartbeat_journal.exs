defmodule WCore.Repo.Migrations.CreateHeartbeatJournal do
  use Ecto.Migration

  def change do
    create table(:heartbeat_journal) do
      add :node_id, references(:nodes, on_delete: :delete_all), null: false
      add :status, :string, null: false
      add :payload, :map, null: false, default: %{}
      add :observed_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:heartbeat_journal, [:node_id])
    create index(:heartbeat_journal, [:inserted_at])
  end
end
