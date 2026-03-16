defmodule DashboardWeb.MetabolicLive.Index do
  use DashboardWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to metabolic spikes via Phoenix.PubSub if needed,
      # or just poll the MetabolicDaemon for now, or subscribe to NATS?
      # For a LiveView, PubSub is best. Let's assume MetabolicDaemon sends PubSub messages.
      # But since we have NATS, we can also bridge NATS to PubSub.
      Phoenix.PubSub.subscribe(Dashboard.PubSub, "metabolic_flux")
    end

    {:ok, assign(socket, metrics: %{l3_misses: 0, run_queue: 0, iops: 0, pressure: :low, atp: 1.0})}
  end

  @impl true
  def handle_info({:metabolic_update, update}, socket) do
    {:noreply, assign(socket, metrics: update)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dashboard-container">
      <header>
        <h1>Karyon Homeostasis Monitor</h1>
        <div class={"status-indicator #{assigns.metrics.pressure}"}>
          System Pressure: <%= String.upcase(to_string(assigns.metrics.pressure)) %>
        </div>
      </header>

      <div class="metrics-grid">
        <div class="metric-card glass">
          <h3>L3 Cache Misses</h3>
          <div class="value"><%= assigns.metrics.l3_misses %></div>
          <p>Baseline: 15k</p>
        </div>

        <div class="metric-card glass">
          <h3>Run Queue Length</h3>
          <div class="value"><%= assigns.metrics.run_queue %></div>
          <p>ERTS Schedulers</p>
        </div>

        <div class="metric-card glass">
          <h3>SSD IOPS</h3>
          <div class="value"><%= assigns.metrics.iops %></div>
          <p>Virtio-blk Throughput</p>
        </div>

        <div class="metric-card glass atp-card">
          <h3>ATP Level</h3>
          <div class="progress-container">
            <div class="progress-bar" style={"width: #{assigns.metrics.atp * 100}%"}></div>
          </div>
          <div class="value text-sm"><%= round(assigns.metrics.atp * 100) %>%</div>
        </div>
      </div>

      <div class="swarm-visualizer glass mt-8">
        <h3>500k Core Swarm Visualization</h3>
        <div id="swarm-canvas-container" phx-update="ignore">
          <canvas id="swarm-canvas" width="800" height="400" phx-hook="SwarmCanvas"></canvas>
        </div>
      </div>
    </div>

    <style>
      .dashboard-container {
        padding: 2rem;
        background: radial-gradient(circle at top right, #1a1a2e, #16213e);
        min-height: 100vh;
        color: #e94560;
        font-family: 'Inter', sans-serif;
      }

      header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 3rem;
        border-bottom: 2px solid #0f3460;
        padding-bottom: 1rem;
      }

      h1 { font-size: 2.5rem; font-weight: 800; color: #fff; letter-spacing: -1px; }

      .status-indicator {
        padding: 0.5rem 1.5rem;
        border-radius: 999px;
        font-weight: bold;
        text-transform: uppercase;
        font-size: 0.9rem;
      }

      .status-indicator.low { background: #00d2ff; color: #000; box-shadow: 0 0 15px #00d2ff88; }
      .status-indicator.medium { background: #f9d423; color: #000; }
      .status-indicator.high { background: #ff4757; color: #fff; box-shadow: 0 0 20px #ff4757aa; animation: pulse 2s infinite; }

      .metrics-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
        gap: 2rem;
      }

      .glass {
        background: rgba(255, 255, 255, 0.03);
        backdrop-filter: blur(12px);
        -webkit-backdrop-filter: blur(12px);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 20px;
        padding: 2rem;
        transition: transform 0.3s ease;
      }

      .glass:hover { transform: translateY(-5px); border-color: rgba(255, 255, 255, 0.2); }

      .metric-card h3 { color: #888; font-size: 1rem; margin-bottom: 1rem; }
      .metric-card .value { font-size: 3rem; font-weight: 800; color: #fff; }

      .atp-card .progress-container {
        width: 100%;
        height: 12px;
        background: #0f3460;
        border-radius: 6px;
        margin-top: 1rem;
        overflow: hidden;
      }

      .atp-card .progress-bar {
        height: 100%;
        background: linear-gradient(90deg, #e94560, #ff4757);
        transition: width 0.5s cubic-bezier(0.175, 0.885, 0.32, 1.275);
      }

      .swarm-visualizer { min-height: 400px; }

      @keyframes pulse {
        0% { opacity: 1; }
        50% { opacity: 0.5; }
        100% { opacity: 1; }
      }
    </style>
    """
  end
end
