defmodule WCore.Telemetry.HeartbeatJournal do
  use Ecto.Schema
  import Ecto.Changeset

  alias WCore.Telemetry.Node

  @statuses [:healthy, :warning, :critical]

  schema "heartbeat_journal" do
    field :status, Ecto.Enum, values: @statuses
    field :payload, :map, default: %{}
    field :observed_at, :utc_datetime_usec
    belongs_to :node, Node

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:node_id, :status, :payload, :observed_at])
    |> validate_required([:node_id, :status, :payload, :observed_at])
    |> assoc_constraint(:node)
  end
end
