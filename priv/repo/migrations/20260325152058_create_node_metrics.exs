defmodule WCore.Repo.Migrations.CreateNodeMetrics do
  use Ecto.Migration

  def change do
    create table(:node_metrics) do
      add :status, :string, null: false
      add :total_events_processed, :integer, null: false, default: 0
      add :last_payload, :map, null: false
      add :last_seen_at, :utc_datetime_usec, null: false
      add :node_id, references(:nodes, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:node_metrics, [:node_id])
  end
end
