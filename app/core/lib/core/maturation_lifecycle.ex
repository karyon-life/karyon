defmodule Core.MaturationLifecycle do
  @moduledoc """
  Typed maturation lifecycle contract for Chapter 12.

  This makes the organism's linguistic grounding curriculum explicit so later
  Chapter 12 work can extend one shared lifecycle surface instead of
  introducing disconnected maturation logic.
  """

  alias Core.ServiceHealth

  @schema "karyon.maturation-lifecycle.v2"
  @babbling_validation "cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/maturation_lifecycle_test.exs"
  @phoneme_validation "cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test apps/rhizome/test"
  @grammar_validation "cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test"
  @semantic_validation "cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test"

  def report(opts \\ []) do
    service_report = Keyword.get_lazy(opts, :service_report, fn -> ServiceHealth.check_all() end)
    dna_root = Keyword.get(opts, :dna_root, dna_root())

    phases = %{
      babbling: babbling_phase(dna_root, opts),
      phoneme_grounding: phoneme_grounding_phase(service_report, opts),
      grammar_consolidation: grammar_consolidation_phase(opts),
      semantic_grounding: semantic_grounding_phase(service_report, opts)
    }

    %{
      schema: @schema,
      overall: overall_status(phases),
      lifecycle: lifecycle_status(phases),
      phases: phases
    }
  end

  def dna_root do
    Application.get_env(:core, :dna_root, Path.expand("../../../../priv/dna", __DIR__))
  end

  defp babbling_phase(root, opts) do
    expanded_root = Path.expand(root)
    sensory_pooler_loaded? = Keyword.get(opts, :sensory_pooler_loaded, false)
    motor_babble_loaded? = Keyword.get(opts, :motor_babble_loaded, false)
    raw_input_ready? = Keyword.get(opts, :raw_input_ready, false)
    raw_output_ready? = Keyword.get(opts, :raw_output_ready, false)
    baseline_dna = baseline_dna_presence(expanded_root)

    blockers =
      []
      |> maybe_add(not sensory_pooler_loaded?, "load the sensory pooler before claiming raw text intake exists")
      |> maybe_add(not motor_babble_loaded?, "load the motor babble boundary before claiming exploratory output exists")
      |> maybe_add(not raw_input_ready?, "wire a raw text or byte intake surface before entering linguistic babbling")
      |> maybe_add(not raw_output_ready?, "wire a bounded babble output surface before entering linguistic babbling")
      |> maybe_add(baseline_dna.missing != [], "create the baseline linguistic DNA set under #{expanded_root} before starting babbling")

    %{
      status: status_from_blockers(blockers),
      objective: "Establish raw intake and bounded babbling before higher-order linguistic grounding dominates.",
      validation: @babbling_validation,
      next_phase: "C12-S02",
      blockers: blockers,
      evidence: %{
        dna_root: expanded_root,
        baseline_dna_present: baseline_dna.present,
        baseline_dna_missing: baseline_dna.missing,
        sensory_pooler_loaded: sensory_pooler_loaded?,
        motor_babble_loaded: motor_babble_loaded?,
        raw_input_ready: raw_input_ready?,
        raw_output_ready: raw_output_ready?
      }
    }
  end

  defp phoneme_grounding_phase(service_report, opts) do
    learning_loop_loaded? = loaded?(opts, :learning_loop_loaded, Core.LearningLoop)
    stem_cell_loaded? = loaded?(opts, :stem_cell_loaded, Core.StemCell)
    pooled_sequences_ready? = Keyword.get(opts, :pooled_sequences_ready, false)
    sensory_memory_ready? = Keyword.get(opts, :sensory_memory_ready, false)
    service_overall = Map.get(service_report, :overall, :degraded)

    blockers =
      []
      |> maybe_add(not learning_loop_loaded?, "load the learning loop contract before promoting pooled sequences into stable phonemic evidence")
      |> maybe_add(not stem_cell_loaded?, "load the stem-cell grounding boundary before treating sensory correlations as reusable evidence")
      |> maybe_add(service_overall != :ok, "restore Memgraph, XTDB, and NATS readiness before relying on grounding-backed maturation")
      |> maybe_add(not pooled_sequences_ready?, "project recurring sensory pools before claiming phoneme grounding exists")
      |> maybe_add(not sensory_memory_ready?, "implement sensory-memory correlation before claiming low-level language units can stabilize")

    %{
      status: status_from_blockers(blockers),
      objective: "Stabilize recurring sensory pools into low-level grounded language units.",
      validation: @phoneme_validation,
      next_phase: "C12-S03",
      blockers: blockers,
      evidence: %{
        service_overall: to_string(service_overall),
        learning_loop_loaded: learning_loop_loaded?,
        stem_cell_loaded: stem_cell_loaded?,
        pooled_sequences_ready: pooled_sequences_ready?,
        sensory_memory_ready: sensory_memory_ready?
      }
    }
  end

  defp grammar_consolidation_phase(opts) do
    consolidation_manager_loaded? = Keyword.get(opts, :consolidation_manager_loaded, false)
    sleep_cycle_ready? = Keyword.get(opts, :sleep_cycle_ready, false)
    grammar_supernodes_ready? = Keyword.get(opts, :grammar_supernodes_ready, false)

    blockers =
      []
      |> maybe_add(not consolidation_manager_loaded?, "load a consolidation manager before claiming grammar can emerge during sleep")
      |> maybe_add(not sleep_cycle_ready?, "implement a sleep-cycle boundary before treating offline abstraction as real maturation")
      |> maybe_add(not grammar_supernodes_ready?, "project recurring linguistic structure into abstract grammar super-nodes before claiming consolidation")

    %{
      status: status_from_blockers(blockers),
      objective: "Consolidate recurring linguistic structure into abstract grammatical organization.",
      validation: @grammar_validation,
      next_phase: "C12-S04",
      blockers: blockers,
      evidence: %{
        consolidation_manager_loaded: consolidation_manager_loaded?,
        sleep_cycle_ready: sleep_cycle_ready?,
        grammar_supernodes_ready: grammar_supernodes_ready?
      }
    }
  end

  defp semantic_grounding_phase(service_report, opts) do
    operator_feedback_ready? = Keyword.get(opts, :operator_feedback_ready, false)
    semantic_feedback_ready? = Keyword.get(opts, :semantic_feedback_ready, false)
    durable_grounding_ready? = Keyword.get(opts, :durable_grounding_ready, false)
    service_overall = Map.get(service_report, :overall, :degraded)

    blockers =
      []
      |> maybe_add(service_overall != :ok, "restore service readiness before claiming semantic grounding can persist")
      |> maybe_add(not operator_feedback_ready?, "load an operator feedback boundary before claiming meaning can be corrected")
      |> maybe_add(not semantic_feedback_ready?, "implement semantic feedback hooks before claiming grounded meaning exists")
      |> maybe_add(not durable_grounding_ready?, "persist durable grounding evidence before claiming semantic stability")

    %{
      status: status_from_blockers(blockers),
      objective: "Link grounded forms to stable meaning through feedback, pruning, and durable evidence.",
      validation: @semantic_validation,
      next_phase: "C12-S05",
      blockers: blockers,
      evidence: %{
        service_overall: to_string(service_overall),
        operator_feedback_ready: operator_feedback_ready?,
        semantic_feedback_ready: semantic_feedback_ready?,
        durable_grounding_ready: durable_grounding_ready?
      }
    }
  end

  defp baseline_dna_presence(root) do
    required = [
      "sensory_pooler_cell.yml",
      "motor_babble_cell.yml",
      "tabula_rasa_stem_cell.yml"
    ]

    present =
      required
      |> Enum.filter(&(File.exists?(Path.join(root, &1))))

    %{
      present: present,
      missing: required -- present
    }
  end

  defp loaded?(opts, key, module) do
    Keyword.get_lazy(opts, key, fn -> Code.ensure_loaded?(module) end)
  end

  defp overall_status(phases) do
    if Enum.all?(phases, fn {_name, phase} -> phase.status == :ok end) do
      :ok
    else
      :degraded
    end
  end

  defp lifecycle_status(phases) do
    if Enum.all?(phases, fn {_name, phase} -> phase.status == :ok end) do
      :ready
    else
      :emerging
    end
  end

  defp status_from_blockers([]), do: :ok
  defp status_from_blockers(_blockers), do: :degraded

  defp maybe_add(list, true, entry), do: list ++ [entry]
  defp maybe_add(list, false, _entry), do: list
end
