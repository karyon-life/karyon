defmodule OperatorEnvironmentWeb.OperatorSandboxLive.Index do
  use OperatorEnvironmentWeb, :live_view

  @sensory_topic NervousSystem.PubSub.topic(:sensory_input)
  @motor_topic NervousSystem.PubSub.topic(:motor_output)
  @telemetry_topic NervousSystem.PubSub.topic(:telemetry)
  @nociception_topic NervousSystem.PubSub.topic(:nociception)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :ok = NervousSystem.PubSub.subscribe(:motor_output)
      :ok = NervousSystem.PubSub.subscribe(:telemetry)
    end

    {:ok,
     assign(socket,
       input_stream: "[\"ALLOW\", \"User_A\", \"READ\", \"Database_X\"]",
       motor_babble: [],
       last_feedback: nil,
       error: nil,
       telemetry: %{
         free_energy: nil,
         pressure: :low,
         consciousness_state: :awake,
         membrane_open: true,
         motor_output_open: true,
         atp: nil,
         run_queue: nil,
         l3_misses: nil,
         iops: nil
       }
     )}
  end

  @impl true
  def handle_event("submit_dsl", %{"dsl_input" => dsl_json}, socket) do
    if socket.assigns.telemetry.membrane_open do
      case Jason.decode(dsl_json) do
        {:ok, tokens} when is_list(tokens) ->
          # Generate deterministic node IDs without the deprecated Quantizer
          node_ids = Enum.map(tokens, fn
            token when is_binary(token) -> :erlang.phash2(token)
            other -> :erlang.phash2(to_string(other))
          end)

          payload = %{
            stream: dsl_json,
            tokens: tokens,
            node_ids: node_ids,
            observed_at: System.monotonic_time(:millisecond),
            source: :operator_induced
          }
          _ = NervousSystem.PubSub.broadcast(@sensory_topic, payload)

          {:noreply, assign(socket, input_stream: dsl_json, error: nil)}

        _ ->
          {:noreply, assign(socket, error: "Invalid DSL Array format. Must be a strict JSON array of strings.")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("confirm_topology", _params, socket) do
    if socket.assigns.telemetry.membrane_open do
      payload = %{
        "feedback_kind" => "approval",
        "template_id" => "sandbox_dsl",
        "target_path" => socket.assigns.input_stream,
        "message" => "Confirm Topology",
        "severity" => 1.0,
        "id" => "operator_feedback:sandbox_dsl:#{System.system_time(:second)}"
      }

      # Record positive feedback via Core.OperatorFeedback (Dopamine analogue)
      _ = Core.OperatorFeedback.record_event(payload)
      
      {:noreply, assign(socket, last_feedback: %{message: "Topology Confirmed (Dopamine Spike)"})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("reject_syntax", _params, socket) do
    if socket.assigns.telemetry.membrane_open do
      payload = %{
        "feedback_kind" => "friction",
        "template_id" => "sandbox_dsl",
        "target_path" => socket.assigns.input_stream,
        "message" => "Reject Syntax",
        "severity" => 1.0,
        "id" => "operator_feedback:sandbox_dsl:#{System.system_time(:second)}"
      }
      
      # Record logic/syntax failure via Core.OperatorFeedback
      _ = Core.OperatorFeedback.record_event(payload)
      
      # Trigger negative Endocrine spike (Nociception) mapping STDP coordinator to decay pathways
      nociception = nociception_payload(1.0, socket.assigns.input_stream, false)
      _ = NervousSystem.PubSub.broadcast(@nociception_topic, nociception)

      {:noreply, assign(socket, last_feedback: %{message: "Syntax Rejected (Nociception Spike)"})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({@motor_topic, %{stream: stream, brief: brief}}, socket) do
    entry = "#{stream}: #{brief.intent_id} -> #{brief.action}"
    {:noreply, update(socket, :motor_babble, fn entries -> Enum.take([entry | entries], 12) end)}
  end

  def handle_info({@motor_topic, payload}, socket) do
    entry = payload |> inspect(pretty: false)
    {:noreply, update(socket, :motor_babble, fn entries -> Enum.take([entry | entries], 12) end)}
  end

  def handle_info({@telemetry_topic, payload}, socket) do
    {:noreply, assign(socket, telemetry: Map.merge(socket.assigns.telemetry, payload))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="operator-shell">
      <header class="masthead">
        <div>
          <p class="eyebrow">Operator Sandbox</p>
          <h1>Action-Friction Harness</h1>
        </div>
        <div class="telemetry-pill">
          Pressure <span>{String.upcase(to_string(@telemetry.pressure || :low))}</span>
        </div>
      </header>

      <section class="zone-grid">
        <section class="zone zone-input">
          <h2>Deterministic DSL Input</h2>
          <p class="zone-copy">Submit strict structural arrays representing spatial relationships. Conversational chat is unconditionally disabled.</p>
          <form phx-submit="submit_dsl" class="dsl-form">
            <input
              type="text"
              name="dsl_input"
              value={@input_stream}
              placeholder="[&quot;ALLOW&quot;, &quot;User_A&quot;, &quot;READ&quot;, &quot;Database_X&quot;]"
              disabled={!@telemetry.membrane_open}
              autocomplete="off"
            />
            <button type="submit" disabled={!@telemetry.membrane_open}>Ingest Vector</button>
          </form>
          <p :if={@error} class="error-msg" style="color: #ff4a4a; margin-top: 10px; font-weight: bold;"><%= @error %></p>
        </section>

        <section class="zone zone-output">
          <h2>Structural Prediction (Motor Babble)</h2>
          <p class="zone-copy">Read-only surface for emitted execution briefs mapping predicted trajectory.</p>
          <textarea id="motor-babble-stream" readonly aria-label="motor babble output"><%= Enum.join(Enum.reverse(@motor_babble), "\n") %></textarea>
        </section>

        <section class="zone zone-feedback">
          <h2>Friction Controls</h2>
          <p class="zone-copy">Evaluate system-generated topologies and force graph plasticity explicitly.</p>
          <div class="feedback-array" style="display: flex; gap: 1rem; margin-top: 1rem;">
            <button type="button" class="btn-confirm" phx-click="confirm_topology" disabled={!@telemetry.membrane_open} style="background-color: #2e8b57; color: white; padding: 0.5rem 1rem; border: none; font-weight: bold; cursor: pointer;">
              Confirm Topology
            </button>
            <button type="button" class="btn-reject" phx-click="reject_syntax" disabled={!@telemetry.membrane_open} style="background-color: #b22222; color: white; padding: 0.5rem 1rem; border: none; font-weight: bold; cursor: pointer;">
              Reject Syntax
            </button>
          </div>
          <p :if={@last_feedback} class="feedback-trace" style="margin-top: 1rem; font-family: monospace; color: #aaa;">
            Last internal state shift: <%= @last_feedback.message %>
          </p>
        </section>

        <section class="zone zone-hud">
          <h2>Variational Free Energy HUD</h2>
          <div class="hud-grid">
            <div>
              <span class="hud-label">Free Energy</span>
              <strong>{format_metric(@telemetry.free_energy)}</strong>
            </div>
            <div>
              <span class="hud-label">ATP</span>
              <strong>{format_metric(@telemetry.atp)}</strong>
            </div>
            <div>
              <span class="hud-label">Run Queue</span>
              <strong>{format_metric(@telemetry.run_queue)}</strong>
            </div>
            <div>
              <span class="hud-label">L3 Misses</span>
              <strong>{format_metric(@telemetry.l3_misses)}</strong>
            </div>
            <div>
              <span class="hud-label">IOPS</span>
              <strong>{format_metric(@telemetry.iops)}</strong>
            </div>
            <div>
              <span class="hud-label">Pressure</span>
              <strong>{String.upcase(to_string(@telemetry.pressure || :low))}</strong>
            </div>
            <div>
              <span class="hud-label">Consciousness</span>
              <strong>{String.upcase(to_string(@telemetry.consciousness_state || :awake))}</strong>
            </div>
            <div>
              <span class="hud-label">Membrane</span>
              <strong>{if @telemetry.membrane_open, do: "OPEN", else: "CLOSED"}</strong>
            </div>
          </div>
        </section>
      </section>
    </div>
    """
  end

  defp nociception_payload(severity, value, bundled) do
    parsed = parse_severity(severity)

    %{
      severity: parsed,
      bundled: bundled,
      bytes: :erlang.binary_to_list(value || <<>>),
      stream: value,
      source: :operator_induced,
      observed_at: System.monotonic_time(:millisecond)
    }
  end

  defp parse_severity(value) when is_float(value), do: clamp(value)
  defp parse_severity(value) when is_integer(value), do: clamp(value * 1.0)

  defp parse_severity(value) when is_binary(value) do
    case Float.parse(value) do
      {parsed, _} -> clamp(parsed)
      :error -> 0.5
    end
  end

  defp parse_severity(_value), do: 0.5

  defp clamp(value), do: value |> max(0.0) |> min(1.0) |> Float.round(2)

  defp format_metric(nil), do: "unavailable"
  defp format_metric(value) when is_float(value), do: format_float(value)
  defp format_metric(value), do: to_string(value)

  defp format_float(value), do: :erlang.float_to_binary(value, decimals: 2)
end
