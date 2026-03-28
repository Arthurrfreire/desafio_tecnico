defmodule WCore.Telemetry.PersistenceWorker do
  @moduledoc false

  use GenServer

  import Ecto.Query, warn: false

  alias WCore.Repo
  alias WCore.Telemetry.HeartbeatJournal
  alias WCore.Telemetry.NodeMetric

  @name __MODULE__

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, Keyword.put_new(opts, :name, @name))
  end

  def flush_now do
    GenServer.call(@name, :flush_now, 30_000)
  end

  @impl true
  def init(state) do
    interval =
      Application.get_env(:w_core, __MODULE__, flush_interval_ms: 1_000)[:flush_interval_ms]

    schedule_flush(interval)
    {:ok, Map.put(state, :flush_interval_ms, interval)}
  end

  @impl true
  def handle_info(:flush, %{flush_interval_ms: interval} = state) do
    persist_cache()
    schedule_flush(interval)
    {:noreply, state}
  end

  @impl true
  def handle_call(:flush_now, _from, state) do
    {:reply, persist_cache(), state}
  end

  defp schedule_flush(interval) do
    Process.send_after(self(), :flush, interval)
  end

  defp persist_cache do
    Repo.transaction(fn ->
      journal_entries =
        Repo.all(from entry in HeartbeatJournal, order_by: [asc: entry.id])

      case journal_entries do
        [] ->
          :ok

        _ ->
          now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
          processed_ids = Enum.map(journal_entries, & &1.id)

          node_ids =
            journal_entries
            |> Enum.map(& &1.node_id)
            |> Enum.uniq()

          current_metrics =
            Repo.all(from metric in NodeMetric, where: metric.node_id in ^node_ids)
            |> Map.new(fn metric ->
              {metric.node_id,
               %{
                 node_id: metric.node_id,
                 status: metric.status,
                 total_events_processed: metric.total_events_processed,
                 last_payload: metric.last_payload || %{},
                 last_seen_at: metric.last_seen_at
               }}
            end)

          consolidated =
            Enum.reduce(journal_entries, current_metrics, fn entry, acc ->
              current =
                Map.get(acc, entry.node_id, %{
                  node_id: entry.node_id,
                  status: nil,
                  total_events_processed: 0,
                  last_payload: %{},
                  last_seen_at: nil
                })

              Map.put(acc, entry.node_id, %{
                current
                | status: entry.status,
                  total_events_processed: current.total_events_processed + 1,
                  last_payload: entry.payload || %{},
                  last_seen_at: entry.observed_at
              })
            end)

          entries =
            Enum.map(consolidated, fn {_node_id, metric} ->
              %{
                node_id: metric.node_id,
                status: metric.status,
                total_events_processed: metric.total_events_processed,
                last_payload: metric.last_payload,
                last_seen_at: metric.last_seen_at,
                inserted_at: now,
                updated_at: now
              }
            end)

          Repo.insert_all(NodeMetric, entries,
            conflict_target: [:node_id],
            on_conflict:
              {:replace,
               [:status, :total_events_processed, :last_payload, :last_seen_at, :updated_at]}
          )

          Repo.delete_all(from entry in HeartbeatJournal, where: entry.id in ^processed_ids)

          :ok
      end
    end)
    |> case do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
    end
  end
end
