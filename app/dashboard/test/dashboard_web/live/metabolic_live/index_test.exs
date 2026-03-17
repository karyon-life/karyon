defmodule DashboardWeb.MetabolicLive.IndexTest do
  use DashboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders live metabolic updates from pubsub", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/metabolism")

    assert html =~ "Karyon Homeostasis Monitor"
    assert html =~ "unavailable"
    assert html =~ "System Pressure: LOW"

    Phoenix.PubSub.broadcast(
      Dashboard.PubSub,
      "metabolic_flux",
      {:metabolic_update,
       %{
         l3_misses: 9_999,
         run_queue: 7,
         iops: 1_234,
         pressure: :high,
         atp: 0.4,
         preflight_status: {:degraded, "memory topology unavailable"}
       }}
    )

    rendered = render(view)

    assert rendered =~ "9999"
    assert rendered =~ "7"
    assert rendered =~ "1234"
    assert rendered =~ "System Pressure: HIGH"
    assert rendered =~ "40%"
  end
end
