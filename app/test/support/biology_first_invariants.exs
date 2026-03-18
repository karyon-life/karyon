defmodule App.TestSupport.BiologyFirstInvariants do
  @moduledoc false

  @repo_root Path.expand("../../", __DIR__)

  def invariants do
    [
      %{
        id: :core_uses_actor_lifecycle,
        description: "core lifecycle remains process-based and decentralized",
        path: "core/lib/core/application.ex",
        required: [":pg.start_link()", "Core.EpigeneticSupervisor", "Core.MetabolicDaemon"],
        forbidden: [":global.register_name", ":ets.new", "Agent.start_link", "Registry.start_link"]
      },
      %{
        id: :epigenetic_supervision_uses_dynamic_supervisor,
        description: "cell lifecycle uses OTP supervision instead of shared mutable coordinators",
        path: "core/lib/core/epigenetic_supervisor.ex",
        required: ["use DynamicSupervisor", "DynamicSupervisor.start_child", "DynamicSupervisor.terminate_child"],
        forbidden: [":global.register_name", ":ets.new", "Agent.start_link"]
      },
      %{
        id: :nervous_system_keeps_decentralized_routing,
        description: "nervous system keeps process-group routing instead of global registries",
        path: "nervous_system/lib/nervous_system/application.ex",
        required: [":pg.start_link()"],
        forbidden: [":global.register_name", "Registry.start_link", ":ets.new"]
      },
      %{
        id: :sandbox_keeps_isolated_vm_supervision,
        description: "sandbox isolates VM lifecycle under a dedicated supervisor boundary",
        path: "sandbox/lib/sandbox/vmm_supervisor.ex",
        required: ["use DynamicSupervisor", "DynamicSupervisor.start_child", "cleanup_resources"],
        forbidden: [":ets.new", ":global.register_name", "Agent.start_link"]
      },
      %{
        id: :rhizome_routes_state_through_memory_boundary,
        description: "memory mutation crosses the Rhizome boundary instead of hidden shared state",
        path: "rhizome/lib/rhizome/memory.ex",
        required: ["def submit_execution_outcome", "def checkpoint_cell_state", "def submit_prediction_error"],
        forbidden: [":ets.new", "Process.put(", "Agent.start_link"]
      }
    ]
  end

  def evaluate do
    Enum.map(invariants(), &evaluate_invariant/1)
  end

  def failures do
    evaluate()
    |> Enum.reject(& &1.pass?)
  end

  def format_failures([]), do: "all biology-first invariants satisfied"

  def format_failures(results) do
    Enum.map_join(results, "\n", fn result ->
      missing =
        result.missing
        |> Enum.map_join(", ", &inspect/1)

      forbidden_hits =
        result.forbidden_hits
        |> Enum.map_join(", ", &inspect/1)

      "#{result.id} failed in #{result.path}; missing=#{missing}; forbidden_hits=#{forbidden_hits}"
    end)
  end

  defp evaluate_invariant(invariant) do
    source = source_for(invariant.path)
    missing = Enum.reject(invariant.required, &String.contains?(source, &1))
    forbidden_hits = Enum.filter(invariant.forbidden, &String.contains?(source, &1))

    Map.merge(invariant, %{
      missing: missing,
      forbidden_hits: forbidden_hits,
      pass?: missing == [] and forbidden_hits == []
    })
  end

  defp source_for(path) do
    path
    |> Path.expand(@repo_root)
    |> File.read!()
  end
end
