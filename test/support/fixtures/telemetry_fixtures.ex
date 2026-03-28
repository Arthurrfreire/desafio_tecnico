defmodule WCore.TelemetryFixtures do
  @moduledoc """
  Test helpers for the Telemetry context.
  """

  def node_fixture(attrs \\ %{}) do
    suffix = System.unique_integer([:positive])

    attrs =
      Enum.into(attrs, %{
        machine_identifier: "MACHINE-#{suffix}",
        location: "Area #{suffix}"
      })

    {:ok, node} = WCore.Telemetry.create_node(attrs)
    node
  end

  def heartbeat_attrs(node, attrs \\ %{}) do
    Enum.into(attrs, %{
      node_id: node.id,
      status: :healthy,
      payload: %{"temperature" => 72, "rpm" => 1200},
      observed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
    })
  end
end
