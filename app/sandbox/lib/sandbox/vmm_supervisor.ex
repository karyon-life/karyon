defmodule Sandbox.VmmSupervisor do
  @moduledoc """
  Manages the dynamic lifecycle of Firecracker MicroVM processes and their
  associated sidecars (log pipes, etc.).
  """
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Spawns a new VMM child under supervision.
  """
  def start_vmm(id, socket_path) do
    child_spec = %{
      id: {:vmm, id},
      start: {Task, :start_link, [fn -> spawn_firecracker(id, socket_path) end]},
      restart: :temporary
    }
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  defp spawn_firecracker(id, socket_path) do
    # Ensure cleanup before starting
    cleanup_resources(id, socket_path)
    
    # In a real environment, this would call the firecracker binary.
    # We use a Task to represent the long-running process.
    if System.get_env("KARYON_MOCK_HARDWARE") == "1" do
      # Mock: create the socket so Sandbox.Firecracker doesn't error
      # In reality, Firecracker creates this immediately on start
      File.touch!(socket_path)
      Process.sleep(:infinity)
    else
      # Actual firecracker execution
      System.cmd("firecracker", ["--api-sock", socket_path], into: IO.stream(:stdio, :line))
    end
  end

  @doc """
  Cleans up VMM resources.
  """
  def cleanup_resources(id, socket_path) do
    File.rm(socket_path)
    # Cleanup taps, iptables via sudo if not mocking
    if System.get_env("KARYON_MOCK_HARDWARE") != "1" do
      System.cmd("sudo", ["ip", "tuntap", "del", "dev", "tap-#{id}", "mode", "tap"])
      # Cleanup specific iptables rules would require more precise targeting
    end
  end
end
