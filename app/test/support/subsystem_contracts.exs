defmodule App.TestSupport.SubsystemContracts do
  @moduledoc false

  @repo_root Path.expand("../../", __DIR__)

  def contracts do
    [
      %{
        id: :nucleus_boundary,
        subsystem: :nucleus,
        path: "core/lib/core",
        description: "the nucleus owns sterile planning, lifecycle, metabolism, and dream-state control",
        required: ["application.ex", "epigenetic_supervisor.ex", "motor_driver.ex", "plan.ex", "stem_cell.ex", "yaml_parser.ex"],
        forbidden: ["pain_receptor.ex", "memory.ex", "dashboard_web"]
      },
      %{
        id: :cytoplasm_boundary,
        subsystem: :cytoplasm,
        path: "core/lib/core/application.ex",
        description: "the cytoplasm boundary boots BEAM process-group and supervision infrastructure",
        required: [":pg.start_link()", "Core.EpigeneticSupervisor", "Core.MetabolicDaemon", "Core.StressTester"],
        forbidden: ["Rhizome.Memory.submit_xtdb", "NervousSystem.Synapse.send_signal("]
      },
      %{
        id: :organelles_boundary,
        subsystem: :organelles,
        path: "rhizome/lib/rhizome",
        description: "organelles own heavy graph and temporal memory operations behind NIF boundaries",
        required: ["native.ex", "raw.ex", "memory.ex", "optimizer.ex", "xtdb.ex"],
        forbidden: ["DashboardWeb", "Core.EpigeneticSupervisor"]
      },
      %{
        id: :membrane_boundary,
        subsystem: :membrane,
        path: "operator_environment/lib/operator_environment",
        description: "the waking-world membrane owns operator conditioning and membrane telemetry surfaces",
        required: ["telemetry_bridge.ex", "application.ex"],
        forbidden: ["Rhizome.Memory.submit_prediction_error"]
      },
      %{
        id: :nervous_system_boundary,
        subsystem: :nervous_system,
        path: "nervous_system/lib/nervous_system",
        description: "the nervous system owns synaptic transport, endocrine signals, pain routing, and membrane bus delivery",
        required: ["synapse.ex", "pain_receptor.ex", "endocrine.ex", "application.ex", "pub_sub.ex"],
        forbidden: ["Rhizome.Native.optimize_graph", "Core.MotorDriver.sequence_plan"]
      }
    ]
  end

  def evaluate do
    Enum.map(contracts(), &evaluate_contract/1)
  end

  def failures do
    evaluate()
    |> Enum.reject(& &1.pass?)
  end

  def format_failures([]), do: "all subsystem contracts satisfied"

  def format_failures(results) do
    Enum.map_join(results, "\n", fn result ->
      missing = Enum.map_join(result.missing, ", ", &inspect/1)
      forbidden_hits = Enum.map_join(result.forbidden_hits, ", ", &inspect/1)
      "#{result.id} failed in #{result.path}; missing=#{missing}; forbidden_hits=#{forbidden_hits}"
    end)
  end

  defp evaluate_contract(contract) do
    source = source_for(contract.path)
    missing = Enum.reject(contract.required, &String.contains?(source, &1))
    forbidden_hits = Enum.filter(contract.forbidden, &String.contains?(source, &1))

    Map.merge(contract, %{
      missing: missing,
      forbidden_hits: forbidden_hits,
      pass?: missing == [] and forbidden_hits == []
    })
  end

  defp source_for(path) do
    path
    |> Path.expand(@repo_root)
    |> then(fn expanded ->
      cond do
        File.dir?(expanded) ->
          expanded
          |> Path.join("**/*")
          |> Path.wildcard()
          |> Enum.filter(&File.regular?/1)
          |> Enum.sort()
          |> Enum.map_join("\n", fn file ->
            "#{Path.basename(file)}\n#{File.read!(file)}"
          end)

        true ->
          File.read!(expanded)
      end
    end)
  end
end
