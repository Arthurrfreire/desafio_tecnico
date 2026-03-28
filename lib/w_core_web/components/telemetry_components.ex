defmodule WCoreWeb.TelemetryComponents do
  @moduledoc false

  use WCoreWeb, :html

  attr :status, :atom, default: nil

  def status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em]",
      status_classes(@status)
    ]}>
      {status_label(@status)}
    </span>
    """
  end

  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :subtitle, :string, default: nil
  attr :tone, :atom, default: :neutral

  def metric_card(assigns) do
    ~H"""
    <section class={[
      "relative overflow-hidden rounded-[1.75rem] border p-5 shadow-sm backdrop-blur-sm transition-transform duration-200 hover:-translate-y-0.5",
      metric_card_classes(@tone)
    ]}>
      <div class={["absolute inset-x-0 top-0 h-1", metric_bar_classes(@tone)]} />
      <p class="text-xs font-semibold uppercase tracking-[0.25em] text-slate-500">{@title}</p>
      <p class="mt-4 text-4xl font-semibold tracking-tight text-slate-950">{@value}</p>
      <p :if={@subtitle} class="mt-2 text-sm text-slate-600">{@subtitle}</p>
    </section>
    """
  end

  attr :node, :map, required: true
  attr :highlighted, :boolean, default: false

  def node_row(assigns) do
    ~H"""
    <tr class={[
      "group border-b border-slate-200/80 align-top transition",
      @highlighted && "node-flash bg-amber-50/80",
      !@highlighted && "hover:bg-slate-50/80"
    ]}>
      <td class="px-5 py-5">
        <p class="font-semibold text-slate-950">{@node.machine_identifier}</p>
        <p class="text-sm text-slate-500">Sensor #{@node.id}</p>
      </td>
      <td class="px-5 py-5 text-slate-700">
        <div class="max-w-xs leading-6">{@node.location}</div>
      </td>
      <td class="px-5 py-5">
        <.status_badge status={@node.status} />
      </td>
      <td class="px-5 py-5">
        <p class="text-lg font-semibold text-slate-950">
          {Integer.to_string(@node.total_events_processed)}
        </p>
        <p class="text-xs uppercase tracking-[0.16em] text-slate-400">processados</p>
      </td>
      <td class="px-5 py-5 text-sm text-slate-600">
        <p class="font-medium text-slate-700">{format_last_seen(@node.last_seen_at)}</p>
        <p class="mt-1 text-xs uppercase tracking-[0.12em] text-slate-400">
          {relative_last_seen(@node.last_seen_at)}
        </p>
      </td>
      <td class="px-5 py-5 text-sm text-slate-600">
        <div class="max-w-xs truncate rounded-2xl border border-slate-200 bg-slate-50 px-3 py-2 font-mono text-xs text-slate-500">
          {format_payload(@node.last_payload)}
        </div>
      </td>
      <td class="px-5 py-5 text-right">
        <span class="inline-flex rounded-full border border-slate-200 bg-white px-3 py-1 text-xs font-medium text-slate-600 shadow-sm">
          leitura ETS
        </span>
      </td>
    </tr>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, required: true

  def empty_state(assigns) do
    ~H"""
    <section class="rounded-3xl border border-dashed border-slate-300 bg-white/70 px-6 py-10 text-center shadow-sm">
      <p class="text-lg font-semibold text-slate-950">{@title}</p>
      <p class="mt-2 text-sm text-slate-600">{@description}</p>
    </section>
    """
  end

  defp status_classes(:healthy), do: "bg-emerald-100 text-emerald-800"
  defp status_classes(:warning), do: "bg-amber-100 text-amber-800"
  defp status_classes(:critical), do: "bg-rose-100 text-rose-800"
  defp status_classes(_), do: "bg-slate-200 text-slate-700"

  defp status_label(:healthy), do: "Healthy"
  defp status_label(:warning), do: "Warning"
  defp status_label(:critical), do: "Critical"
  defp status_label(_), do: "No signal"

  defp metric_card_classes(:healthy), do: "border-emerald-200 bg-white/90"
  defp metric_card_classes(:warning), do: "border-amber-200 bg-white/90"
  defp metric_card_classes(:critical), do: "border-rose-200 bg-white/90"
  defp metric_card_classes(:neutral), do: "border-slate-200 bg-white/90"

  defp metric_bar_classes(:healthy), do: "bg-emerald-300"
  defp metric_bar_classes(:warning), do: "bg-amber-300"
  defp metric_bar_classes(:critical), do: "bg-rose-300"
  defp metric_bar_classes(:neutral), do: "bg-slate-300"

  defp format_last_seen(nil), do: "Sem heartbeat"

  defp format_last_seen(last_seen_at) do
    Calendar.strftime(last_seen_at, "%d/%m/%Y • %H:%M:%S")
  end

  defp relative_last_seen(nil), do: "aguardando sinal"

  defp relative_last_seen(last_seen_at) do
    seconds = max(DateTime.diff(DateTime.utc_now(), last_seen_at, :second), 0)

    cond do
      seconds < 5 -> "agora"
      seconds < 60 -> "ha #{seconds}s"
      seconds < 3_600 -> "ha #{div(seconds, 60)} min"
      true -> "ha #{div(seconds, 3_600)} h"
    end
  end

  defp format_payload(payload) when payload in [%{}, nil], do: "payload vazio"

  defp format_payload(payload) do
    payload
    |> Jason.encode!()
    |> String.slice(0, 72)
  end
end
