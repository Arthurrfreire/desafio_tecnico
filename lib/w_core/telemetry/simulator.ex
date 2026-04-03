defmodule WCore.Telemetry.Simulator do
  @moduledoc """
  Monte Carlo-style heartbeat simulator for local demos.

  The simulator runs inside the same BEAM instance as the application and exercises
  the public `Telemetry.ingest_heartbeat/1` API. This means the dashboard reacts
  through the real ingestion path instead of bypassing ETS, PubSub or persistence.
  """

  use GenServer

  alias WCore.Telemetry

  @name __MODULE__
  @default_duration_seconds 30
  @default_interval_ms 300
  @default_min_events_per_tick 1
  @default_max_events_per_tick 2
  @default_burst_probability 0.12
  @default_burst_extra_events 2

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, Keyword.put_new(opts, :name, @name))
  end

  def start(opts \\ []) do
    GenServer.call(@name, {:start, opts}, 30_000)
  end

  def stop do
    GenServer.call(@name, :stop, 30_000)
  end

  def status do
    GenServer.call(@name, :status, 30_000)
  end

  @impl true
  def init(_state) do
    :rand.seed(
      :exsplus,
      {:erlang.system_time(), :erlang.unique_integer([:positive]), :erlang.phash2(node())}
    )

    {:ok, idle_state()}
  end

  @impl true
  def handle_call({:start, opts}, _from, state) do
    nodes = Telemetry.list_dashboard_nodes()

    if nodes == [] do
      {:reply, {:error, :no_nodes}, state}
    else
      state =
        state
        |> cancel_timer()
        |> build_running_state(opts)
        |> schedule_tick(0)

      {:reply, {:ok, public_status(state)}, state}
    end
  end

  def handle_call(:stop, _from, state) do
    {:reply, :ok, state |> cancel_timer() |> idle_state_from()}
  end

  def handle_call(:status, _from, state) do
    {:reply, public_status(state), state}
  end

  @impl true
  def handle_info({:tick, tick_ref}, %{tick_ref: tick_ref} = state) do
    if simulation_expired?(state) do
      {:noreply, state |> cancel_timer() |> idle_state_from()}
    else
      nodes = Telemetry.list_dashboard_nodes()
      burst? = burst?(state)
      events = generate_heartbeats(nodes, state, burst?)

      emitted =
        Enum.reduce(events, 0, fn heartbeat, acc ->
          case Telemetry.ingest_heartbeat(heartbeat) do
            :ok -> acc + 1
            _ -> acc
          end
        end)

      state =
        state
        |> Map.update!(:ticks, &(&1 + 1))
        |> Map.update!(:events_emitted, &(&1 + emitted))
        |> schedule_tick(state.interval_ms)

      {:noreply, state}
    end
  end

  def handle_info({:tick, _stale_ref}, state) do
    {:noreply, state}
  end

  defp idle_state do
    %{
      running?: false,
      timer_ref: nil,
      tick_ref: nil,
      started_at: nil,
      started_at_unix_ms: nil,
      duration_ms: nil,
      interval_ms: @default_interval_ms,
      min_events_per_tick: @default_min_events_per_tick,
      max_events_per_tick: @default_max_events_per_tick,
      burst_probability: @default_burst_probability,
      burst_extra_events: @default_burst_extra_events,
      ticks: 0,
      events_emitted: 0
    }
  end

  defp idle_state_from(state) do
    state
    |> Map.merge(idle_state())
  end

  defp build_running_state(state, opts) do
    duration_ms = simulation_duration_ms(opts)
    interval_ms = Keyword.get(opts, :interval_ms, @default_interval_ms)

    state
    |> Map.put(:running?, true)
    |> Map.put(:started_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> Map.put(:started_at_unix_ms, System.monotonic_time(:millisecond))
    |> Map.put(:duration_ms, duration_ms)
    |> Map.put(:interval_ms, interval_ms)
    |> Map.put(
      :min_events_per_tick,
      Keyword.get(opts, :min_events_per_tick, @default_min_events_per_tick)
    )
    |> Map.put(
      :max_events_per_tick,
      Keyword.get(opts, :max_events_per_tick, @default_max_events_per_tick)
    )
    |> Map.put(
      :burst_probability,
      Keyword.get(opts, :burst_probability, @default_burst_probability)
    )
    |> Map.put(
      :burst_extra_events,
      Keyword.get(opts, :burst_extra_events, @default_burst_extra_events)
    )
    |> Map.put(:ticks, 0)
    |> Map.put(:events_emitted, 0)
  end

  defp simulation_duration_ms(opts) do
    cond do
      Keyword.has_key?(opts, :duration_ms) ->
        Keyword.fetch!(opts, :duration_ms)

      Keyword.has_key?(opts, :duration_seconds) ->
        Keyword.fetch!(opts, :duration_seconds) * 1_000

      true ->
        @default_duration_seconds * 1_000
    end
  end

  defp schedule_tick(state, delay_ms) do
    tick_ref = make_ref()
    timer_ref = Process.send_after(self(), {:tick, tick_ref}, delay_ms)
    %{state | timer_ref: timer_ref, tick_ref: tick_ref}
  end

  defp cancel_timer(%{timer_ref: nil} = state), do: state

  defp cancel_timer(%{timer_ref: timer_ref} = state) do
    Process.cancel_timer(timer_ref)
    %{state | timer_ref: nil, tick_ref: nil}
  end

  defp simulation_expired?(%{running?: false}), do: true

  defp simulation_expired?(%{duration_ms: nil}), do: false

  defp simulation_expired?(state) do
    elapsed_ms = System.monotonic_time(:millisecond) - state.started_at_unix_ms
    elapsed_ms >= state.duration_ms
  end

  defp burst?(state) do
    :rand.uniform() <= state.burst_probability
  end

  defp generate_heartbeats(nodes, state, burst?) do
    total_events =
      Enum.random(state.min_events_per_tick..state.max_events_per_tick) +
        if(burst?, do: state.burst_extra_events, else: 0)

    Enum.map(1..total_events, fn _ ->
      node = Enum.random(nodes)
      status = next_status(node.status, burst?)

      %{
        node_id: node.id,
        status: status,
        payload: build_payload(node.machine_identifier, status, burst?),
        observed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
      }
    end)
  end

  defp next_status(current_status, burst?) do
    current_status
    |> transition_weights(burst?)
    |> weighted_pick()
  end

  defp transition_weights(nil, false), do: [{:healthy, 70}, {:warning, 20}, {:critical, 10}]
  defp transition_weights(nil, true), do: [{:healthy, 35}, {:warning, 35}, {:critical, 30}]

  defp transition_weights(:healthy, false), do: [{:healthy, 78}, {:warning, 17}, {:critical, 5}]
  defp transition_weights(:healthy, true), do: [{:healthy, 30}, {:warning, 40}, {:critical, 30}]

  defp transition_weights(:warning, false), do: [{:healthy, 22}, {:warning, 53}, {:critical, 25}]
  defp transition_weights(:warning, true), do: [{:healthy, 10}, {:warning, 45}, {:critical, 45}]

  defp transition_weights(:critical, false), do: [{:healthy, 8}, {:warning, 37}, {:critical, 55}]
  defp transition_weights(:critical, true), do: [{:healthy, 5}, {:warning, 25}, {:critical, 70}]

  defp weighted_pick(weighted_values) do
    total_weight = Enum.reduce(weighted_values, 0, fn {_value, weight}, acc -> acc + weight end)
    threshold = :rand.uniform(total_weight)

    Enum.reduce_while(weighted_values, threshold, fn {value, weight}, remaining ->
      if remaining <= weight do
        {:halt, value}
      else
        {:cont, remaining - weight}
      end
    end)
  end

  defp build_payload(machine_identifier, status, burst?) do
    base_payload =
      case machine_profile(machine_identifier) do
        :press ->
          %{
            "temperature" => sample_temperature(status, burst?, 68, 93, 121),
            "rpm" => sample_rpm(status, 860, 940, 1_020),
            "pressure" => sample_pressure(status, 102, 118, 136)
          }

        :furnace ->
          %{
            "temperature" => sample_temperature(status, burst?, 410, 560, 715),
            "airflow" => sample_pressure(status, 64, 78, 92),
            "fuel_pressure" => sample_pressure(status, 110, 124, 140)
          }

        :cnc ->
          %{
            "temperature" => sample_temperature(status, burst?, 58, 84, 109),
            "rpm" => sample_rpm(status, 1_200, 1_480, 1_760),
            "vibration" => sample_pressure(status, 2, 5, 8)
          }

        :pack ->
          %{
            "motor_temp" => sample_temperature(status, burst?, 45, 66, 88),
            "throughput" => sample_rpm(status, 78, 64, 48),
            "reject_rate" => sample_pressure(status, 1, 3, 7)
          }

        :generic ->
          %{
            "temperature" => sample_temperature(status, burst?, 60, 88, 110),
            "rpm" => sample_rpm(status, 900, 980, 1_050),
            "load" => sample_pressure(status, 42, 61, 79)
          }
      end

    Map.merge(base_payload, %{
      "simulated" => true,
      "mode" => "monte_carlo",
      "burst" => burst?
    })
  end

  defp machine_profile(machine_identifier) do
    cond do
      String.starts_with?(machine_identifier, "PRESS") -> :press
      String.starts_with?(machine_identifier, "FURNACE") -> :furnace
      String.starts_with?(machine_identifier, "CNC") -> :cnc
      String.starts_with?(machine_identifier, "PACK") -> :pack
      true -> :generic
    end
  end

  defp sample_temperature(:healthy, false, base, _warning, _critical),
    do: rand_between(base - 4, base + 6)

  defp sample_temperature(:healthy, true, _base, warning, _critical),
    do: rand_between(warning - 4, warning + 6)

  defp sample_temperature(:warning, _burst?, _base, warning, _critical),
    do: rand_between(warning - 3, warning + 8)

  defp sample_temperature(:critical, _burst?, _base, _warning, critical),
    do: rand_between(critical - 4, critical + 10)

  defp sample_rpm(:healthy, healthy, _warning, _critical), do: healthy + rand_between(-35, 35)
  defp sample_rpm(:warning, _healthy, warning, _critical), do: warning + rand_between(-45, 45)
  defp sample_rpm(:critical, _healthy, _warning, critical), do: critical + rand_between(-60, 60)

  defp sample_pressure(:healthy, healthy, _warning, _critical), do: healthy + rand_between(-3, 3)
  defp sample_pressure(:warning, _healthy, warning, _critical), do: warning + rand_between(-3, 4)

  defp sample_pressure(:critical, _healthy, _warning, critical),
    do: critical + rand_between(-4, 5)

  defp rand_between(min, max) when min <= max do
    Enum.random(min..max)
  end

  defp public_status(state) do
    %{
      running?: state.running?,
      started_at: state.started_at,
      duration_ms: state.duration_ms,
      interval_ms: state.interval_ms,
      min_events_per_tick: state.min_events_per_tick,
      max_events_per_tick: state.max_events_per_tick,
      burst_probability: state.burst_probability,
      burst_extra_events: state.burst_extra_events,
      ticks: state.ticks,
      events_emitted: state.events_emitted
    }
  end
end
