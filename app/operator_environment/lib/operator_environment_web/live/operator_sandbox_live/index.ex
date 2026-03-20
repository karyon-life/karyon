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
       input_stream: "",
       feedback_multiplier: 0.5,
       motor_babble: [],
       last_feedback: nil,
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
  def handle_event("stream_bytes", %{"value" => value}, socket) do
    if socket.assigns.telemetry.membrane_open do
    payload = %{
      bytes: :erlang.binary_to_list(value),
      stream: value,
      observed_at: System.monotonic_time(:millisecond)
    }

      _ = NervousSystem.PubSub.broadcast(@sensory_topic, payload)

      {:noreply, assign(socket, input_stream: value)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("adjust_feedback", %{"severity" => severity}, socket) do
    {:noreply, assign(socket, feedback_multiplier: parse_severity(severity))}
  end

  def handle_event("inject_feedback", %{"severity" => severity}, socket) do
    if socket.assigns.telemetry.membrane_open do
      payload = nociception_payload(severity, socket.assigns.input_stream, false)
      _ = NervousSystem.PubSub.broadcast(@nociception_topic, payload)
      {:noreply, assign(socket, last_feedback: payload)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("bundle_input", %{"value" => value, "severity" => severity}, socket) do
    if socket.assigns.telemetry.membrane_open do
      payload = nociception_payload(severity, value, true)
      _ = NervousSystem.PubSub.broadcast(@sensory_topic, payload)
      _ = NervousSystem.PubSub.broadcast(@nociception_topic, payload)

      {:noreply,
       socket
       |> assign(:input_stream, value)
       |> assign(:feedback_multiplier, payload.severity)
       |> assign(:last_feedback, payload)}
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
          <h1>Waking-World Conditioning Membrane</h1>
        </div>
        <div class="telemetry-pill">
          Pressure <span>{String.upcase(to_string(@telemetry.pressure || :low))}</span>
        </div>
      </header>

      <section class="zone-grid">
        <section class="zone zone-input">
          <h2>Continuous Byte Stream</h2>
          <p class="zone-copy">`phx-keyup` streams the raw byte field continuously. `Shift+Enter` emits one bundled websocket event with the current severity multiplier.</p>
          <textarea
            id="sensory-stream"
            phx-keyup="stream_bytes"
            phx-hook="MacroInput"
            data-severity-target="nociception-multiplier"
            aria-label="continuous byte stream"
            disabled={!@telemetry.membrane_open}
          ><%= @input_stream %></textarea>
        </section>

        <section class="zone zone-output">
          <h2>Motor Babble Output</h2>
          <p class="zone-copy">Read-only surface for emitted motor babble and operator-facing execution briefs.</p>
          <textarea id="motor-babble-stream" readonly aria-label="motor babble output"><%= Enum.join(Enum.reverse(@motor_babble), "\n") %></textarea>
        </section>

        <section class="zone zone-feedback">
          <h2>Biological Feedback Array</h2>
          <p class="zone-copy">Inject variable `metabolic.spike` severity as typed numeric values.</p>
          <div class="multiplier-row">
            <label for="nociception-multiplier">Severity multiplier</label>
            <input
              id="nociception-multiplier"
              type="range"
              min="0"
              max="1"
              step="0.1"
              value={@feedback_multiplier}
              phx-change="adjust_feedback"
              name="severity"
              disabled={!@telemetry.membrane_open}
            />
            <span class="multiplier-value">{format_float(@feedback_multiplier)}</span>
          </div>
          <div class="feedback-array">
            <button type="button" phx-click="inject_feedback" phx-value-severity="0.2" disabled={!@telemetry.membrane_open}>Inject 0.2</button>
            <button type="button" phx-click="inject_feedback" phx-value-severity="0.5" disabled={!@telemetry.membrane_open}>Inject 0.5</button>
            <button type="button" phx-click="inject_feedback" phx-value-severity="0.8" disabled={!@telemetry.membrane_open}>Inject 0.8</button>
          </div>
          <p :if={@last_feedback} class="feedback-trace">
            Last feedback: severity={format_float(@last_feedback.severity)} bundled={@last_feedback.bundled}
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
      bytes: :erlang.binary_to_list(value),
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
