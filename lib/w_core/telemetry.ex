defmodule WCore.Telemetry do
  @moduledoc """
  API boundary for sensor registry, hot state and persisted metrics.
  """

  import Ecto.Query, warn: false

  alias WCore.Repo
  alias WCore.Telemetry.Heartbeat
  alias WCore.Telemetry.Ingestor
  alias WCore.Telemetry.Node
  alias WCore.Telemetry.NodeMetric
  alias WCore.Telemetry.PersistenceWorker
  alias WCore.Telemetry.Simulator

  @cache_table :w_core_telemetry_cache
  @status_topic "telemetry:status_changes"

  def cache_table, do: @cache_table
  def status_topic, do: @status_topic

  def subscribe_status_changes do
    Phoenix.PubSub.subscribe(WCore.PubSub, @status_topic)
  end

  def list_nodes do
    Repo.all(from node in Node, order_by: [asc: node.machine_identifier])
  end

  def get_node!(id), do: Repo.get!(Node, id)

  def create_node(attrs \\ %{}) do
    with {:ok, node} <-
           %Node{}
           |> Node.changeset(attrs)
           |> Repo.insert() do
      Ingestor.add_node(node.id)
      {:ok, node}
    end
  end

  def update_node(%Node{} = node, attrs) do
    node
    |> Node.changeset(attrs)
    |> Repo.update()
  end

  def delete_node(%Node{} = node) do
    with {:ok, deleted_node} <- Repo.delete(node) do
      Ingestor.remove_node(deleted_node.id)
      {:ok, deleted_node}
    end
  end

  def change_node(%Node{} = node, attrs \\ %{}) do
    Node.changeset(node, attrs)
  end

  def get_node_metric_by_node_id(node_id) do
    Repo.get_by(NodeMetric, node_id: node_id)
  end

  def list_dashboard_nodes do
    list_nodes()
    |> Enum.map(&merge_node_with_snapshot/1)
  end

  def get_node_snapshot(node_id) do
    case Repo.get(Node, node_id) do
      %Node{} = node -> merge_node_with_snapshot(node)
      nil -> nil
    end
  end

  def ingest_heartbeat(attrs) do
    with {:ok, heartbeat} <- Heartbeat.validate(attrs) do
      Ingestor.ingest(heartbeat)
    end
  end

  def flush_metrics do
    PersistenceWorker.flush_now()
  end

  def start_simulation(opts \\ []) do
    Simulator.start(opts)
  end

  def stop_simulation do
    Simulator.stop()
  end

  def simulation_status do
    Simulator.status()
  end

  defp merge_node_with_snapshot(%Node{} = node) do
    snapshot =
      case :ets.lookup(@cache_table, node.id) do
        [{_node_id, status, total_events_processed, last_payload, last_seen_at}] ->
          %{
            status: status,
            total_events_processed: total_events_processed,
            last_payload: last_payload || %{},
            last_seen_at: last_seen_at
          }

        [] ->
          %{
            status: nil,
            total_events_processed: 0,
            last_payload: %{},
            last_seen_at: nil
          }
      end

    Map.merge(
      %{
        id: node.id,
        machine_identifier: node.machine_identifier,
        location: node.location
      },
      snapshot
    )
  end
end
