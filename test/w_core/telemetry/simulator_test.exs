defmodule WCore.Telemetry.SimulatorTest do
  use WCore.DataCase, async: false

  import WCore.TelemetryFixtures

  alias WCore.Telemetry

  describe "Monte Carlo simulation" do
    test "emits heartbeats through the domain API and stops after the configured duration" do
      node = node_fixture(machine_identifier: "PRESS-01")

      assert {:ok, status} =
               Telemetry.start_simulation(
                 duration_ms: 120,
                 interval_ms: 10,
                 min_events_per_tick: 1,
                 max_events_per_tick: 1,
                 burst_probability: 0.0,
                 burst_extra_events: 0
               )

      assert status.running?

      assert eventually(fn ->
               snapshot = Telemetry.get_node_snapshot(node.id)
               snapshot && snapshot.total_events_processed > 0
             end)

      assert eventually(fn ->
               Telemetry.simulation_status().running? == false
             end)
    end

    test "returns an explicit error when there are no nodes to simulate" do
      assert {:error, :no_nodes} = Telemetry.start_simulation(duration_ms: 50)
    end
  end

  defp eventually(fun, attempts \\ 40)

  defp eventually(fun, attempts) when attempts > 0 do
    if fun.() do
      true
    else
      Process.sleep(25)
      eventually(fun, attempts - 1)
    end
  end

  defp eventually(_fun, 0), do: false
end
