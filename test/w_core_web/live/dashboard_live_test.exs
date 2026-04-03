defmodule WCoreWeb.DashboardLiveTest do
  use WCoreWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import WCore.TelemetryFixtures

  alias WCore.Telemetry

  test "requires authentication", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/dashboard")
  end

  describe "authenticated dashboard" do
    setup :register_and_log_in_user

    test "renders nodes and reacts to status changes", %{conn: conn} do
      node = node_fixture(machine_identifier: "PRESS-01", location: "Linha A")

      {:ok, view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Planta 42"
      assert html =~ "PRESS-01"
      assert render(view) =~ "No signal"
      assert html =~ "Simulação Monte Carlo"

      assert :ok =
               Telemetry.ingest_heartbeat(
                 heartbeat_attrs(node, %{status: :critical, payload: %{"temperature" => 110}})
               )

      assert eventually(fn -> render(view) =~ "Critical" end)
    end

    test "can start the Monte Carlo simulator from the dashboard", %{conn: conn} do
      node = node_fixture(machine_identifier: "PRESS-01", location: "Linha A")
      on_exit(fn -> Telemetry.stop_simulation() end)

      {:ok, view, _html} = live(conn, ~p"/dashboard")

      view
      |> element("button[phx-value-duration=\"30\"]")
      |> render_click()

      assert eventually(fn ->
               snapshot = Telemetry.get_node_snapshot(node.id)
               snapshot.total_events_processed > 0
             end)

      assert eventually(fn -> render(view) =~ "rodando" end)
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
