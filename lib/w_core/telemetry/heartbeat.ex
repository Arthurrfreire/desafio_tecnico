defmodule WCore.Telemetry.Heartbeat do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @statuses [:healthy, :warning, :critical]

  embedded_schema do
    field :node_id, :integer
    field :status, Ecto.Enum, values: @statuses
    field :payload, :map
    field :observed_at, :utc_datetime_usec
  end

  def validate(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:validate)
  end

  defp changeset(heartbeat, attrs) do
    heartbeat
    |> cast(attrs, [:node_id, :status, :payload, :observed_at])
    |> validate_required([:node_id, :status, :payload])
    |> put_default_observed_at()
  end

  defp put_default_observed_at(changeset) do
    case get_field(changeset, :observed_at) do
      nil ->
        put_change(changeset, :observed_at, DateTime.utc_now() |> DateTime.truncate(:microsecond))

      _ ->
        changeset
    end
  end
end
