defmodule WCore.TelemetryTest do
  use WCore.DataCase, async: false

  alias WCore.Telemetry
  alias WCore.Telemetry.HeartbeatJournal
  alias WCore.Telemetry.Ingestor
  alias WCore.Telemetry.Node

  import WCore.TelemetryFixtures

  describe "node registry" do
    test "create_node/1 stores static sensor metadata" do
      assert {:ok, %Node{} = node} =
               Telemetry.create_node(%{
                 machine_identifier: "PRESS-99",
                 location: "Linha de Teste"
               })

      assert node.machine_identifier == "PRESS-99"
      assert node.location == "Linha de Teste"
      assert [%Node{}] = Telemetry.list_nodes()
    end

    test "create_node/1 rejects invalid data" do
      assert {:error, changeset} =
               Telemetry.create_node(%{
                 machine_identifier: nil,
                 location: nil
               })

      assert %{machine_identifier: ["can't be blank"], location: ["can't be blank"]} =
               errors_on(changeset)
    end
  end

  describe "heartbeat ingestion" do
    test "ingest_heartbeat/1 updates ETS immediately and journals the heartbeat durably" do
      node = node_fixture()

      assert :ok =
               Telemetry.ingest_heartbeat(
                 heartbeat_attrs(node, %{status: :warning, payload: %{"temperature" => 91}})
               )

      snapshot = Telemetry.get_node_snapshot(node.id)

      assert snapshot.status == :warning
      assert snapshot.total_events_processed == 1
      assert snapshot.last_payload == %{"temperature" => 91}
      assert snapshot.last_seen_at
      assert Repo.aggregate(HeartbeatJournal, :count, :id) == 1
    end

    test "flush_metrics/0 persists the consolidated state to sqlite and drains the journal" do
      node = node_fixture()

      assert :ok = Telemetry.ingest_heartbeat(heartbeat_attrs(node, %{status: :healthy}))
      assert :ok = Telemetry.ingest_heartbeat(heartbeat_attrs(node, %{status: :critical}))
      assert Repo.aggregate(HeartbeatJournal, :count, :id) == 2
      assert :ok = Telemetry.flush_metrics()

      metric = Telemetry.get_node_metric_by_node_id(node.id)

      assert metric.status == :critical
      assert metric.total_events_processed == 2
      assert metric.last_payload["rpm"] == 1200
      assert Repo.aggregate(HeartbeatJournal, :count, :id) == 0
    end

    test "ingestor restart reloads ETS from durable journal before flush without losing counts" do
      node = node_fixture()

      assert :ok = Telemetry.ingest_heartbeat(heartbeat_attrs(node, %{status: :warning}))
      assert :ok = Telemetry.ingest_heartbeat(heartbeat_attrs(node, %{status: :critical}))
      assert Repo.aggregate(HeartbeatJournal, :count, :id) == 2

      original_pid = Process.whereis(Ingestor)
      Process.exit(original_pid, :kill)

      assert eventually(fn ->
               pid = Process.whereis(Ingestor)
               pid && pid != original_pid
             end)

      assert eventually(fn ->
               snapshot = Telemetry.get_node_snapshot(node.id)
               snapshot.total_events_processed == 2 and snapshot.status == :critical
             end)

      assert Repo.aggregate(HeartbeatJournal, :count, :id) == 2
    end

    test "ingestor restart reloads ETS from sqlite after flush without losing counts" do
      node = node_fixture()

      assert :ok = Telemetry.ingest_heartbeat(heartbeat_attrs(node, %{status: :warning}))
      assert :ok = Telemetry.flush_metrics()

      original_pid = Process.whereis(Ingestor)
      Process.exit(original_pid, :kill)

      assert eventually(fn ->
               pid = Process.whereis(Ingestor)
               pid && pid != original_pid
             end)

      assert eventually(fn ->
               snapshot = Telemetry.get_node_snapshot(node.id)
               snapshot.total_events_processed == 1 and snapshot.status == :warning
             end)

      assert Repo.aggregate(HeartbeatJournal, :count, :id) == 0
    end

    test "10_000 concurrent heartbeats preserve counts in ETS and sqlite" do
      nodes_with_status =
        [
          {node_fixture(machine_identifier: "PRESS-01"), :healthy},
          {node_fixture(machine_identifier: "FURNACE-02"), :warning},
          {node_fixture(machine_identifier: "CNC-03"), :critical}
        ]

      expected_counts =
        Enum.reduce(1..10_000, %{}, fn index, acc ->
          {node, _status} = Enum.at(nodes_with_status, rem(index - 1, length(nodes_with_status)))
          Map.update(acc, node.id, 1, &(&1 + 1))
        end)

      1..10_000
      |> Task.async_stream(
        fn index ->
          {node, status} = Enum.at(nodes_with_status, rem(index - 1, length(nodes_with_status)))

          Telemetry.ingest_heartbeat(
            heartbeat_attrs(node, %{
              status: status,
              payload: %{"sequence" => index}
            })
          )
        end,
        max_concurrency: 200,
        ordered: false,
        timeout: 60_000
      )
      |> Enum.each(fn result ->
        assert result == {:ok, :ok}
      end)

      assert :ok = Telemetry.flush_metrics()

      Enum.each(nodes_with_status, fn {node, status} ->
        snapshot = Telemetry.get_node_snapshot(node.id)
        metric = Telemetry.get_node_metric_by_node_id(node.id)

        assert snapshot.total_events_processed == expected_counts[node.id]
        assert snapshot.status == status
        assert metric.total_events_processed == expected_counts[node.id]
        assert metric.status == status
      end)

      assert Repo.aggregate(HeartbeatJournal, :count, :id) == 0
    end
  end

  defp eventually(fun, attempts \\ 20)

  defp eventually(fun, attempts) when attempts > 0 do
    if fun.() do
      true
    else
      Process.sleep(50)
      eventually(fun, attempts - 1)
    end
  end

  defp eventually(_fun, 0), do: false
end
