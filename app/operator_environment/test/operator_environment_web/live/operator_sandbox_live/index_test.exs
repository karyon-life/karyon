defmodule OperatorEnvironmentWeb.OperatorSandboxLive.IndexTest do
  use OperatorEnvironmentWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup do
    Application.put_env(:nervous_system, :membrane_state_override, %{
      consciousness_state: :awake,
      membrane_open: true,
      motor_output_open: true
    })

    :ok = NervousSystem.PubSub.subscribe(:sensory_input)
    :ok = NervousSystem.PubSub.subscribe(:nociception)

    on_exit(fn ->
      Application.delete_env(:nervous_system, :membrane_state_override)
    end)

    :ok
  end

  test "renders the four operator zones and streams bytes over keyup", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")

    assert html =~ "Continuous Byte Stream"
    assert html =~ "Motor Babble Output"
    assert html =~ "Biological Feedback Array"
    assert html =~ "Variational Free Energy HUD"
    assert html =~ "phx-keyup"
    assert html =~ "readonly"

    render_keyup(view, "stream_bytes", %{"value" => "hello"})

    assert_received {"nervous_system:sensory_input", %{stream: "hello", bytes: [104, 101, 108, 108, 111]}}
  end

  test "injects typed metabolic feedback and bundles shift-enter input", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    render_click(element(view, "button[phx-value-severity=\"0.8\"]"))

    assert_received {"nervous_system:nociception", %{severity: 0.8, bundled: false, source: :operator_induced}}

    render_hook(view, "bundle_input", %{"value" => "bundle", "severity" => "0.9"})

    assert_received {"nervous_system:sensory_input", %{stream: "bundle", severity: 0.9, bundled: true}}
    assert_received {"nervous_system:nociception", %{stream: "bundle", severity: 0.9, bundled: true}}
  end

  test "updates the motor babble stream and free-energy hud from organism telemetry", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    :ok =
      NervousSystem.PubSub.broadcast(:motor_output, %{
        stream: "motor_babble",
        brief: %{intent_id: "intent:1", action: "babble"}
      })

    :ok =
      NervousSystem.PubSub.broadcast(:telemetry, %{
        free_energy: 0.42,
        atp: 0.88,
        pressure: :high,
        run_queue: 7
      })

    rendered = render(view)

    assert rendered =~ "intent:1 -&gt; babble"
    assert rendered =~ "0.42"
    assert rendered =~ "0.88"
    assert rendered =~ "HIGH"
    assert rendered =~ "7"
  end

  test "locks and rejects operator input server-side when the membrane is closed", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    Application.put_env(:nervous_system, :membrane_state_override, %{
      consciousness_state: :torpor,
      membrane_open: false,
      motor_output_open: false
    })

    :ok =
      NervousSystem.PubSub.broadcast(:telemetry, %{
        pressure: :high,
        consciousness_state: :torpor,
        membrane_open: false,
        motor_output_open: false
      })

    rendered = render(view)
    assert rendered =~ "TORPOR"
    assert rendered =~ "CLOSED"
    assert rendered =~ "disabled"

    render_keyup(view, "stream_bytes", %{"value" => "blocked"})
    render_hook(view, "bundle_input", %{"value" => "blocked-bundle", "severity" => "0.9"})

    refute_received {"nervous_system:sensory_input", %{stream: "blocked", bytes: _}}
    refute_received {"nervous_system:sensory_input", %{stream: "blocked-bundle", severity: 0.9, bundled: true}}
    refute_received {"nervous_system:nociception", %{stream: "blocked-bundle", severity: 0.9, bundled: true}}
  end
end
