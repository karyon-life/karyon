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

  test "renders the operator zones and action-friction controls", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Action-Friction Harness"
    assert html =~ "Deterministic DSL Input"
    assert html =~ "Structural Prediction"
    assert html =~ "Friction Controls"
    assert html =~ "Confirm Topology"
    assert html =~ "Reject Syntax"
  end

  test "submits valid DSL array to the quantizer and broadcasts sensory_input", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    valid_json = "[\"ALLOW\", \"User_A\", \"READ\", \"Database_X\"]"
    
    view
    |> form(".dsl-form", %{"dsl_input" => valid_json})
    |> render_submit()

    assert_received {"nervous_system:sensory_input", payload}
    assert payload.source == :operator_induced
    assert payload.stream == valid_json
    assert payload.tokens == ["ALLOW", "User_A", "READ", "Database_X"]
    assert is_list(payload.node_ids)
    assert length(payload.node_ids) == 4
  end

  test "shows error when invalid non-array JSON is submitted", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    invalid_json = "{\"hello\": \"world\"}"
    
    html =
      view
      |> form(".dsl-form", %{"dsl_input" => invalid_json})
      |> render_submit()

    assert html =~ "Invalid DSL Array format. Must be a strict JSON array of strings."
    refute_received {"nervous_system:sensory_input", _}
  end

  test "injects positive dopamine analogue via confirm_topology", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    render_click(element(view, ".btn-confirm"))

    # Verify UI updates to show last feedback
    assert render(view) =~ "Topology Confirmed (Dopamine Spike)"
  end

  test "injects negative nociception spike and triggers decay via reject_syntax", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    render_click(element(view, ".btn-reject"))

    assert_received {"nervous_system:nociception", %{severity: 1.0, source: :operator_induced}}
    assert render(view) =~ "Syntax Rejected (Nociception Spike)"
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

    view
    |> form(".dsl-form", %{"dsl_input" => "[\"TEST\"]"})
    |> render_submit()

    render_click(element(view, ".btn-confirm"))
    render_click(element(view, ".btn-reject"))

    refute_received {"nervous_system:sensory_input", _}
    refute_received {"nervous_system:nociception", _}
  end
end
