defmodule WCoreWeb.DashboardLive do
  use WCoreWeb, :live_view

  import WCoreWeb.TelemetryComponents

  alias WCore.Telemetry

  @refresh_interval_ms 1_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Telemetry.subscribe_status_changes()
      schedule_refresh()
    end

    nodes = Telemetry.list_dashboard_nodes()

    {:ok,
     socket
     |> assign(:page_title, "Planta 42")
     |> assign(:highlighted_node_id, nil)
     |> assign_dashboard(nodes)}
  end

  @impl true
  def handle_info(:refresh_dashboard, socket) do
    schedule_refresh()
    {:noreply, assign_dashboard(socket, Telemetry.list_dashboard_nodes())}
  end

  @impl true
  def handle_info({:status_changed, node_id}, socket) do
    case Telemetry.get_node_snapshot(node_id) do
      nil ->
        {:noreply, socket}

      node ->
        Process.send_after(self(), {:clear_highlight, node_id}, 1_500)

        {:noreply,
         socket
         |> assign(:highlighted_node_id, node_id)
         |> assign_dashboard(replace_node(socket.assigns.nodes, node))}
    end
  end

  @impl true
  def handle_info(
        {:clear_highlight, node_id},
        %{assigns: %{highlighted_node_id: node_id}} = socket
      ) do
    {:noreply, assign(socket, :highlighted_node_id, nil)}
  end

  def handle_info({:clear_highlight, _node_id}, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      main_class="px-0 py-0"
      container_class="max-w-none space-y-0"
    >
      <section class="w-core-shell min-h-screen px-4 py-6 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-screen-2xl space-y-6">
          <section class="grid gap-6 xl:grid-cols-[minmax(0,1.55fr)_minmax(360px,0.85fr)]">
            <header class="overflow-hidden rounded-[2rem] border border-slate-200/70 bg-white/85 px-8 py-8 shadow-sm backdrop-blur-sm">
              <div class="flex flex-col gap-6">
                <p class="text-xs font-semibold uppercase tracking-[0.32em] text-slate-500">
                  Sala de Controle
                </p>
                <h1 class="text-4xl font-semibold tracking-tight text-slate-950 sm:text-5xl">
                  Planta 42
                </h1>
                <p class="max-w-3xl text-base leading-7 text-slate-600">
                  Dashboard reativo com leitura quente via ETS e persistência consolidada em SQLite.
                </p>
                <div class="flex flex-wrap gap-3">
                  <span class="rounded-full border border-slate-200 bg-slate-50 px-4 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-600">
                    ETS first
                  </span>
                  <span class="rounded-full border border-slate-200 bg-slate-50 px-4 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-600">
                    Flush a cada 1s
                  </span>
                  <span class="rounded-full border border-slate-200 bg-slate-50 px-4 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-600">
                    PubSub por transição
                  </span>
                </div>
              </div>
            </header>

            <aside class="rounded-[2rem] border border-slate-900/70 bg-slate-950 px-6 py-6 text-slate-100 shadow-sm">
              <p class="text-xs font-semibold uppercase tracking-[0.28em] text-slate-400">
                Operação atual
              </p>
              <div class="mt-5">
                <p class="text-sm text-slate-400">Operador logado</p>
                <p class="mt-2 text-lg font-medium break-all">{@current_scope.user.email}</p>
              </div>

              <div class="mt-6 grid gap-3 sm:grid-cols-2 xl:grid-cols-1 2xl:grid-cols-2">
                <div class="rounded-[1.5rem] border border-white/10 bg-white/5 p-4">
                  <p class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-400">
                    Último sinal
                  </p>
                  <p class="mt-3 text-sm leading-6 text-slate-200">
                    {@overview.latest_heartbeat_label}
                  </p>
                </div>

                <div class="rounded-[1.5rem] border border-white/10 bg-white/5 p-4">
                  <p class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-400">
                    Maior volume
                  </p>
                  <p class="mt-3 text-lg font-semibold text-white">
                    {@overview.busiest_machine_label}
                  </p>
                </div>
              </div>

              <div class="mt-6 rounded-[1.5rem] border border-amber-400/20 bg-amber-300/10 p-4">
                <p class="text-xs font-semibold uppercase tracking-[0.18em] text-amber-200">
                  Sensores em observação
                </p>
                <p class="mt-3 text-3xl font-semibold text-white">
                  {Integer.to_string(@overview.attention_nodes)}
                </p>
                <p class="mt-2 text-sm leading-6 text-slate-300">
                  Warning e critical ficam concentrados aqui para leitura operacional rapida.
                </p>
              </div>
            </aside>
          </section>

          <section class="grid gap-4 md:grid-cols-2 xl:grid-cols-5">
            <.metric_card
              title="Total de sensores"
              value={Integer.to_string(@summary.total_nodes)}
              subtitle="Cadastro estático da planta"
            />
            <.metric_card
              title="Eventos totais"
              value={Integer.to_string(@summary.total_events)}
              subtitle="Contagem agregada em memória"
            />
            <.metric_card
              title="Healthy"
              value={Integer.to_string(@summary.healthy)}
              subtitle="Operação nominal"
              tone={:healthy}
            />
            <.metric_card
              title="Warning"
              value={Integer.to_string(@summary.warning)}
              subtitle="Atenção necessária"
              tone={:warning}
            />
            <.metric_card
              title="Critical"
              value={Integer.to_string(@summary.critical)}
              subtitle="Intervenção imediata"
              tone={:critical}
            />
          </section>

          <section :if={@nodes == []}>
            <.empty_state
              title="Nenhum sensor cadastrado"
              description="Rode as seeds para popular a planta com alguns nós iniciais antes de abrir o painel."
            />
          </section>

          <section
            :if={@nodes != []}
            class="grid gap-6 xl:grid-cols-[minmax(0,1.75fr)_minmax(300px,0.8fr)]"
          >
            <div class="overflow-hidden rounded-[2rem] border border-slate-200/70 bg-white/90 shadow-sm backdrop-blur-sm">
              <div class="flex flex-col gap-4 border-b border-slate-200/80 px-6 py-5 sm:flex-row sm:items-end sm:justify-between">
                <div>
                  <h2 class="text-lg font-semibold text-slate-950">Estado corrente das máquinas</h2>
                  <p class="text-sm text-slate-500">
                    Mudanças de status chegam por PubSub; contadores e heartbeat são atualizados a cada segundo.
                  </p>
                </div>
                <p class="text-xs font-semibold uppercase tracking-[0.25em] text-slate-400">
                  {@overview.latest_refresh_label}
                </p>
              </div>

              <div class="overflow-x-auto">
                <table class="min-w-full text-left">
                  <thead class="bg-slate-50/90 text-xs uppercase tracking-[0.2em] text-slate-500">
                  <tr>
                    <th class="px-5 py-4 font-semibold">Máquina</th>
                    <th class="px-5 py-4 font-semibold">Localização</th>
                    <th class="px-5 py-4 font-semibold">Status</th>
                    <th class="px-5 py-4 font-semibold">Eventos</th>
                    <th class="px-5 py-4 font-semibold">Último heartbeat</th>
                    <th class="px-5 py-4 font-semibold">Payload</th>
                    <th class="px-5 py-4 font-semibold text-right">Fonte</th>
                  </tr>
                  </thead>
                  <tbody>
                    <.node_row
                      :for={node <- @nodes}
                      node={node}
                      highlighted={@highlighted_node_id == node.id}
                    />
                  </tbody>
                </table>
              </div>
            </div>

            <aside class="space-y-6">
              <section class="rounded-[2rem] border border-slate-200/70 bg-white/90 p-6 shadow-sm backdrop-blur-sm">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-500">
                      Foco operacional
                    </p>
                    <h3 class="mt-2 text-xl font-semibold text-slate-950">Pontos de Atenção</h3>
                  </div>
                  <span class="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">
                    {Integer.to_string(length(@attention_nodes))} itens
                  </span>
                </div>

                <div class="mt-5 space-y-3">
                  <div
                    :for={node <- @attention_nodes}
                    class="rounded-[1.5rem] border border-slate-200 bg-slate-50/80 p-4"
                  >
                    <div class="flex items-start justify-between gap-3">
                      <div>
                        <p class="font-semibold text-slate-950">{node.machine_identifier}</p>
                        <p class="mt-1 text-sm leading-6 text-slate-600">{node.location}</p>
                      </div>
                      <.status_badge status={node.status} />
                    </div>
                    <p class="mt-3 text-xs uppercase tracking-[0.14em] text-slate-400">
                      {Integer.to_string(node.total_events_processed)} eventos • {overview_time(node.last_seen_at)}
                    </p>
                  </div>

                  <div
                    :if={@attention_nodes == []}
                    class="rounded-[1.5rem] border border-emerald-200 bg-emerald-50/80 p-4 text-sm leading-6 text-emerald-900"
                  >
                    Todos os sensores estao em `healthy` neste momento.
                  </div>
                </div>
              </section>

              <section class="rounded-[2rem] border border-slate-200/70 bg-white/90 p-6 shadow-sm backdrop-blur-sm">
                <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-500">
                  Como ler este painel
                </p>
                <div class="mt-4 space-y-4 text-sm leading-6 text-slate-600">
                  <p>
                    A tabela sempre lê o estado quente direto da ETS para manter a resposta imediata.
                  </p>
                  <p>
                    O destaque amarelado aparece apenas quando um sensor troca de status.
                  </p>
                  <p>
                    O SQLite continua como persistência consolidada, sincronizada em segundo plano.
                  </p>
                </div>
              </section>
            </aside>
          </section>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh_dashboard, @refresh_interval_ms)
  end

  defp assign_dashboard(socket, nodes) do
    assign(socket, :nodes, nodes)
    |> assign(:summary, summarize(nodes))
    |> assign(:attention_nodes, attention_nodes(nodes))
    |> assign(:overview, build_overview(nodes))
  end

  defp summarize(nodes) do
    Enum.reduce(
      nodes,
      %{total_nodes: length(nodes), total_events: 0, healthy: 0, warning: 0, critical: 0},
      fn node, acc ->
        acc
        |> Map.update!(:total_events, &(&1 + node.total_events_processed))
        |> increment_status(node.status)
      end
    )
  end

  defp increment_status(acc, :healthy), do: Map.update!(acc, :healthy, &(&1 + 1))
  defp increment_status(acc, :warning), do: Map.update!(acc, :warning, &(&1 + 1))
  defp increment_status(acc, :critical), do: Map.update!(acc, :critical, &(&1 + 1))
  defp increment_status(acc, _), do: acc

  defp attention_nodes(nodes) do
    Enum.filter(nodes, &(&1.status in [:warning, :critical]))
  end

  defp build_overview(nodes) do
    latest_node =
      Enum.max_by(nodes, &datetime_to_unix(&1.last_seen_at), fn -> nil end)

    busiest_node =
      Enum.max_by(nodes, & &1.total_events_processed, fn -> nil end)

    %{
      attention_nodes: Enum.count(nodes, &(&1.status in [:warning, :critical])),
      latest_heartbeat_label: latest_heartbeat_label(latest_node),
      busiest_machine_label: busiest_machine_label(busiest_node),
      latest_refresh_label: latest_refresh_label(),
      latest_seen_at: latest_node && latest_node.last_seen_at
    }
  end

  defp latest_heartbeat_label(nil), do: "Sem heartbeat registrado"

  defp latest_heartbeat_label(node) do
    "#{node.machine_identifier} • #{overview_time(node.last_seen_at)}"
  end

  defp busiest_machine_label(nil), do: "Sem dados"

  defp busiest_machine_label(node) do
    "#{node.machine_identifier} (#{node.total_events_processed})"
  end

  defp latest_refresh_label do
    "Atualizado em #{Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")}"
  end

  defp overview_time(nil), do: "sem sinal"

  defp overview_time(last_seen_at) do
    Calendar.strftime(last_seen_at, "%d/%m • %H:%M:%S")
  end

  defp datetime_to_unix(nil), do: 0
  defp datetime_to_unix(datetime), do: DateTime.to_unix(datetime, :microsecond)

  defp replace_node(nodes, updated_node) do
    Enum.map(nodes, fn node ->
      if node.id == updated_node.id, do: updated_node, else: node
    end)
  end
end
