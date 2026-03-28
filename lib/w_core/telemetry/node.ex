defmodule WCore.Telemetry.Node do
  use Ecto.Schema
  import Ecto.Changeset

  alias WCore.Telemetry.NodeMetric

  schema "nodes" do
    field :machine_identifier, :string
    field :location, :string
    has_one :node_metric, NodeMetric

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(node, attrs) do
    node
    |> cast(attrs, [:machine_identifier, :location])
    |> validate_required([:machine_identifier, :location])
    |> unique_constraint(:machine_identifier)
  end
end
