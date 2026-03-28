defmodule WCore.Telemetry.NodeMetric do
  use Ecto.Schema
  import Ecto.Changeset

  alias WCore.Telemetry.Node

  @statuses [:healthy, :warning, :critical]

  schema "node_metrics" do
    field :status, Ecto.Enum, values: @statuses
    field :total_events_processed, :integer, default: 0
    field :last_payload, :map, default: %{}
    field :last_seen_at, :utc_datetime_usec
    belongs_to :node, Node

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(node_metric, attrs) do
    node_metric
    |> cast(attrs, [:node_id, :status, :total_events_processed, :last_payload, :last_seen_at])
    |> validate_required([
      :node_id,
      :status,
      :total_events_processed,
      :last_payload,
      :last_seen_at
    ])
    |> assoc_constraint(:node)
    |> unique_constraint(:node_id)
  end
end
