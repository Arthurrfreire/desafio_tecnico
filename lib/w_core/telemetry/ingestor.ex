defmodule WCore.Telemetry.Ingestor do
  @moduledoc false

  use GenServer

  import Ecto.Query, warn: false

  alias WCore.Repo
  alias WCore.Telemetry
  alias WCore.Telemetry.Heartbeat
  alias WCore.Telemetry.HeartbeatJournal
  alias WCore.Telemetry.Node
  alias WCore.Telemetry.NodeMetric

  @name __MODULE__
  @cache_table Telemetry.cache_table()

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, Keyword.put_new(opts, :name, @name))
  end

  def ingest(%Heartbeat{} = heartbeat) do
    GenServer.call(@name, {:ingest, heartbeat}, 30_000)
  end

  def add_node(node_id) do
    GenServer.cast(@name, {:add_node, node_id})
  end

  def remove_node(node_id) do
    GenServer.cast(@name, {:remove_node, node_id})
  end

  def reload_state do
    GenServer.call(@name, :reload_state, 30_000)
  end

  @impl true
  def init(state) do
    ensure_cache_table()
    load_persisted_state_into_cache()

    {:ok, Map.put(state, :known_node_ids, load_known_node_ids())}
  end

  @impl true
  def handle_call(
        {:ingest, %Heartbeat{} = heartbeat},
        _from,
        %{known_node_ids: known_node_ids} = state
      ) do
    if MapSet.member?(known_node_ids, heartbeat.node_id) do
      case persist_heartbeat(heartbeat) do
        {:ok, _entry} ->
          {cache_record, status_changed?} = build_cache_record(heartbeat)
          :ets.insert(@cache_table, cache_record)

          if status_changed? do
            Phoenix.PubSub.broadcast(
              WCore.PubSub,
              Telemetry.status_topic(),
              {:status_changed, heartbeat.node_id}
            )
          end

          {:reply, :ok, state}

        {:error, _reason} ->
          {:reply, {:error, :persistence_failed}, state}
      end
    else
      {:reply, {:error, :node_not_found}, state}
    end
  end

  @impl true
  def handle_call(:reload_state, _from, state) do
    ensure_cache_table()
    load_persisted_state_into_cache()

    {:reply, :ok, %{state | known_node_ids: load_known_node_ids()}}
  end

  @impl true
  def handle_cast({:add_node, node_id}, %{known_node_ids: known_node_ids} = state) do
    {:noreply, %{state | known_node_ids: MapSet.put(known_node_ids, node_id)}}
  end

  @impl true
  def handle_cast({:remove_node, node_id}, %{known_node_ids: known_node_ids} = state) do
    :ets.delete(@cache_table, node_id)

    {:noreply, %{state | known_node_ids: MapSet.delete(known_node_ids, node_id)}}
  end

  defp ensure_cache_table do
    case :ets.whereis(@cache_table) do
      :undefined ->
        :ets.new(@cache_table, [:named_table, :set, :protected, read_concurrency: true])

      _tid ->
        :ets.delete_all_objects(@cache_table)
        @cache_table
    end
  end

  defp load_known_node_ids do
    safe_repo_all(from node in Node, select: node.id)
    |> MapSet.new()
  end

  defp load_metrics_into_cache do
    for metric <- safe_repo_all(NodeMetric) do
      :ets.insert(@cache_table, {
        metric.node_id,
        metric.status,
        metric.total_events_processed,
        metric.last_payload || %{},
        metric.last_seen_at
      })
    end
  end

  defp load_persisted_state_into_cache do
    load_metrics_into_cache()

    for journal_entry <- pending_journal_entries() do
      journal_entry
      |> heartbeat_from_journal_entry()
      |> build_cache_record()
      |> elem(0)
      |> then(&:ets.insert(@cache_table, &1))
    end
  end

  defp build_cache_record(%Heartbeat{} = heartbeat) do
    {previous_status, previous_count} =
      case :ets.lookup(@cache_table, heartbeat.node_id) do
        [{_node_id, status, total_events_processed, _last_payload, _last_seen_at}] ->
          {status, total_events_processed}

        [] ->
          {nil, 0}
      end

    cache_record = {
      heartbeat.node_id,
      heartbeat.status,
      previous_count + 1,
      heartbeat.payload,
      heartbeat.observed_at
    }

    {cache_record, previous_status != heartbeat.status}
  end

  defp pending_journal_entries do
    safe_repo_all(from entry in HeartbeatJournal, order_by: [asc: entry.id])
  end

  defp heartbeat_from_journal_entry(entry) do
    %Heartbeat{
      node_id: entry.node_id,
      status: entry.status,
      payload: entry.payload || %{},
      observed_at: entry.observed_at
    }
  end

  defp persist_heartbeat(%Heartbeat{} = heartbeat) do
    %HeartbeatJournal{}
    |> HeartbeatJournal.changeset(%{
      node_id: heartbeat.node_id,
      status: heartbeat.status,
      payload: heartbeat.payload,
      observed_at: heartbeat.observed_at
    })
    |> Repo.insert()
  end

  defp safe_repo_all(queryable) do
    Repo.all(queryable)
  rescue
    _ -> []
  end
end
