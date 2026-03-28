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

      assert :ok =
               Telemetry.ingest_heartbeat(
                 heartbeat_attrs(node, %{status: :critical, payload: %{"temperature" => 110}})
               )

      assert eventually(fn -> render(view) =~ "Critical" end)
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
