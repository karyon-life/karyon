defmodule Core.StemCell do
  @moduledoc """
  The behavioral template for Karyon cells (Actors).
  Implements the `gen_server` behavior, binding to `pg` (Process Groups)
  and initializing ZeroMQ (:chumak) Synaptic connections for deterministic execution.
  """
  use GenServer
  require Logger

  @doc """
  Spawns a new Stem Cell given a declarative DNA specification.
  """
  def start_link(dna_path) do
    GenServer.start_link(__MODULE__, dna_path)
  end

  def start(dna_path) do
    GenServer.start(__MODULE__, dna_path)
  end

  @impl true
  def init(dna_source) do
    dna = load_dna!(dna_source)
    dna_spec = Core.DNA.to_spec(dna)
    full_path = dna.file_path
    lineage_id = Core.DNA.lineage_id(dna)
    group_topic = Core.DNA.role(dna)

    Logger.info("Genesis: Stem Cell Booting from #{full_path}")

    # Phase 1/2 Integration: Decentralized Process Discovery via Erlang :pg
    Enum.each(routing_topics(group_topic, lineage_id), &:pg.join(&1, self()))

    # Phase 2 Integration: Synaptic Zero-Buffer connections
    synapses = 
      case Map.get(dna_spec, "synapses", []) do
        [] -> []
        syn_configs when is_list(syn_configs) ->
          Enum.map(syn_configs, fn config ->
            start_synapse(config)
          end)
        syn_config when is_map(syn_config) ->
            [start_synapse(syn_config)]
      end

    # Phase 1: Self-subscribe to the Pain Receptor as an "Eye" for the organism
    nociception_address = Application.get_env(:nervous_system, :nociception_port, 5555)
    
    bind_uri = case nociception_address do
      addr when is_binary(addr) -> addr
      port when is_integer(port) -> "tcp://127.0.0.1:#{port}"
    end

    {:ok, nociception_syn_pid} = NervousSystem.Synapse.start_link(
      type: :sub, 
      bind: bind_uri, 
      action: :connect,
      hwm: 500
    )

    # Subscribe to metabolic spikes via NATS (Endocrine system)
    endocrine_topic = "metabolic.spike"
    
    recovered_state = hydrate_state(lineage_id, full_path)

    state =
      %{
      dna: dna,
      control_plane: dna.control_plane,
      dna_spec: dna_spec,
      synapses: [nociception_syn_pid | synapses], 
      expectations: %{}, # Map of id -> typed expectation records
      beliefs: %{},
      status: :active,
      lineage_id: lineage_id,
      dna_path: full_path,
      atp_metabolism: 1.0 # Current metabolic health (1.0 = optimal)
    }
      |> merge_recovered_state(recovered_state)

    # Register for endocrine signals if NATS is up
    case GenServer.whereis(:endocrine_gnat) do
      nil -> :ok
      pid -> NervousSystem.Endocrine.subscribe(pid, endocrine_topic)
    end

    checkpoint_state(state)
    {:ok, state}
  end

  @impl true
  def handle_call({:execute, action, params}, _from, state) do
    allowed_actions = Core.DNA.allowed_actions(state.dna)
    cond do
      action not in allowed_actions ->
        Logger.error("[StemCell] ACTION DENIED: #{action} not in DNA allowed_actions.")
        {:reply, {:error, :unauthorized}, state}

      below_execution_budget?(state) ->
        Logger.warning("[StemCell] ACTION DENIED: #{action} exceeds current ATP budget.")
        persisted_state = checkpoint_state(state)
        {:reply, {:error, :insufficient_atp}, persisted_state}

      true ->
        Logger.info("[StemCell] Executing allowed action: #{action}")
      
        # Phase 1: Dynamic Dispatch based on DNA
        case dispatch_motor_action(state.dna_spec, action, params) do
          {:ok, result} ->
            persist_execution_outcome(state, action, params, {:ok, result})
            reinforce_rhizome_pathways(state.expectations)
            {:reply, {:ok, result}, checkpoint_state(state)}

          {:error, reason} ->
            persist_execution_outcome(state, action, params, {:error, reason})
            persist_prediction_error(execution_failure_payload(state, action, params, reason))
            {:reply, {:error, reason}, checkpoint_state(state)}

          # Catch-all for dynamic dispatch safety
          other ->
            persist_execution_outcome(state, action, params, {:ok, other})
            {:reply, {:ok, other}, checkpoint_state(state)}
        end
    end
  end

  @impl true
  def handle_call({:form_expectation, id, goal, precision}, _from, state) do
    handle_call({:form_expectation, id, goal, precision, %{}}, self(), state)
  end

  @impl true
  def handle_call({:form_expectation, id, goal, precision, attrs}, _from, state) do
    expectation = build_expectation(id, goal, precision, attrs, state)
    Logger.info("[StemCell] Forming expectation: #{inspect(expectation.goal)} with precision #{expectation.precision}")
    new_expectations = Map.put(state.expectations, id, expectation)
    {:reply, :ok, checkpoint_state(%{state | expectations: new_expectations})}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_call(:get_synapse_count, _from, state) do
    {:reply, length(state.synapses), state}
  end

  @impl true
  def handle_call(:get_runtime_state, _from, state) do
    runtime_state =
      Map.take(state, [:lineage_id, :dna_path, :beliefs, :expectations, :status, :atp_metabolism])
      |> Map.put(:role, Core.DNA.role(state.dna))
      |> Map.put(:safety_critical, Core.DNA.safety_critical?(state.dna))

    {:reply, runtime_state, state}
  end

  @impl true
  def handle_call({:lifecycle_transition, transition, metadata}, _from, state) do
    case apply_lifecycle_transition(state, transition, normalize_metadata_map(metadata)) do
      {:stop, reason, next_state} ->
        {:stop, reason, :ok, checkpoint_state(next_state)}

      next_state ->
        {:reply, :ok, checkpoint_state(next_state)}
    end
  end

  defp dispatch_motor_action(dna_spec, action, params) do
    with {:ok, executor_spec} <- resolve_executor(dna_spec),
         {:ok, module, function} <- resolve_executor_target(executor_spec) do
      invoke_executor(module, function, executor_payload(dna_spec, action, params, executor_spec))
    else
      {:error, :executor_not_configured} ->
        Logger.warning("[StemCell] No declarative executor defined for this cell.")
        {:error, :executor_not_configured}

      {:error, {:invalid_executor_module, module_name}} ->
        Logger.warning("[StemCell] Invalid executor module: #{inspect(module_name)}.")
        {:error, {:invalid_executor_module, module_name}}

      {:error, {:invalid_executor_function, function_name}} ->
        Logger.warning("[StemCell] Invalid executor function: #{inspect(function_name)}.")
        {:error, {:invalid_executor_function, function_name}}
    end
  end

  @impl true
  def handle_info({:msg, %{body: iodata, topic: topic}}, state) do
    handle_info({:msg, topic, iodata}, state)
  end

  def handle_info({:msg, _topic, iodata}, state) do
    payload = IO.iodata_to_binary(iodata)
    # Handle NATS Metabolic Spikes (Endocrine system)
    case Karyon.NervousSystem.MetabolicSpike.decode(payload) do
      {:ok, %Karyon.NervousSystem.MetabolicSpike{severity: "high"}} ->
        Logger.error("[StemCell] CRITICAL Metabolic Stress. Shedding synapses and entering Digital Torpor.")
        case apply_lifecycle_transition(state, :high_pressure, %{"source" => "metabolic.spike"}) do
          {:stop, reason, next_state} -> {:stop, reason, checkpoint_state(next_state)}
          next_state -> {:noreply, checkpoint_state(next_state)}
        end

      {:ok, %Karyon.NervousSystem.MetabolicSpike{severity: "medium"}} ->
        case apply_lifecycle_transition(state, :medium_pressure, %{"source" => "metabolic.spike"}) do
          {:stop, reason, next_state} -> {:stop, reason, checkpoint_state(next_state)}
          next_state -> {:noreply, checkpoint_state(next_state)}
        end

      {:ok, %Karyon.NervousSystem.MetabolicSpike{severity: "low"}} ->
        {:noreply, checkpoint_state(apply_lifecycle_transition(state, :low_pressure, %{"source" => "metabolic.spike"}))}

      {:error, reason} ->
        Logger.debug("[StemCell] Failed to decode metabolic spike: #{inspect(reason)}. Payload length: #{byte_size(payload)}")
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:synapse_recv, _pid, iodata}, state) do
    payload = IO.iodata_to_binary(iodata)
    case Karyon.NervousSystem.PredictionError.decode(payload) do
      {:ok, %Karyon.NervousSystem.PredictionError{} = prediction_error} ->
        Logger.warning("[StemCell] Received Nociception Signal! Calculating Variational Free Energy.")
        
        # Calculate Variational Free Energy (F)
        metadata = normalize_prediction_metadata(prediction_error.metadata)
        expectation_lineage = expectation_lineage(state.expectations)
        vfe = calculate_variational_free_energy(state.expectations, metadata)

        utility_threshold = Core.DNA.utility_threshold(state.dna)
        next_state =
          %{state | expectations: %{}}
          |> put_in([:beliefs], Map.merge(state.beliefs, %{
            last_vfe: vfe,
            last_prediction_metadata: metadata,
            last_expectation_lineage: expectation_lineage
          }))

        persist_prediction_error(
          nociception_payload(next_state, prediction_error, metadata, vfe, utility_threshold, expectation_lineage)
        )

        if vfe > utility_threshold do
          Logger.error("[StemCell] VFE #{vfe} exceeds threshold #{utility_threshold}. Triggering structural pruning.")
          # Pruning logic: remove failed branches in the Rhizome
          prune_rhizome_pathways(state.expectations)
        end
        
        {:noreply, checkpoint_state(next_state)}
      _ ->
        {:noreply, state}
    end
  end

  @doc """
  Senses the "gradient" of available cells for a specific role/topic.
  Returns a random PID from the Process Group, mimicking stigmergy-based discovery.
  """
  def sense_gradient(role, opts \\ []) do
    excluded_pid = Keyword.get(opts, :exclude)

    members =
      role_members(role)
      |> Enum.reject(&(&1 == excluded_pid))

    case members do
      [] -> {:error, :no_gradient_detected}
      members -> {:ok, Enum.random(members)}
    end
  end

  @doc """
  Returns the live members advertising a given cell role through the structured routing topics.
  """
  def role_members(role) do
    role
    |> role_topics()
    |> Enum.flat_map(&:pg.get_members/1)
    |> Enum.filter(&Process.alive?/1)
    |> Enum.uniq()
  end

  defp calculate_variational_free_energy(expectations, metadata) do
    Enum.reduce(expectations, 0.0, fn {id, expectation}, acc ->
      prediction_error = prediction_error_signal(id, expectation, metadata)
      acc + expectation.precision * expectation.objective_weight * prediction_error
    end)
  end

  defp routing_topics(role, lineage_id) do
    [:stem_cell, role, {:cell_role, role}, {:lineage, lineage_id}]
  end

  defp role_topics(role) do
    normalized_role =
      case role do
        topic when is_binary(topic) -> String.to_atom(topic)
        topic -> topic
      end

    [normalized_role, {:cell_role, normalized_role}]
  end

  defp start_synapse(config) do
    type = String.to_atom(Map.get(config, "type", "push"))
    bind = Map.get(config, "bind", "tcp://127.0.0.1:0")

    case NervousSystem.Synapse.start_link(type: type, bind: bind) do
      {:ok, pid} -> pid
      {:error, reason} ->
        Logger.error("[StemCell] Failed to start synapse: #{inspect(reason)}. Continuing differentiation.")
        nil
    end
  end

  defp hydrate_state(lineage_id, full_path) do
    case memory_module().load_cell_state(lineage_id) do
      {:ok, recovered_state} when is_map(recovered_state) ->
        recovered_state
        |> Map.put_new("dna_path", full_path)
        |> Map.put_new("lineage_id", lineage_id)

      _ ->
        %{
          "beliefs" => %{},
          "expectations" => %{},
          "status" => "active",
          "atp_metabolism" => 1.0,
          "dna_path" => full_path,
          "lineage_id" => lineage_id
        }
    end
  end

  defp prune_rhizome_pathways(expectations) do
    Enum.each(expectations, fn {id, expectation} ->
      pathway =
        plasticity_pathway(expectation)
        |> Map.put(:weight_delta, prune_weight_delta(expectation))

      Logger.info("[StemCell] Requesting Rhizome pruning for: #{id}")

      case rhizome_module().prune_pathway(pathway) do
        {:ok, _} -> :ok
        {:error, reason} -> Logger.warning("[StemCell] Failed to prune pathway for #{id}: #{inspect(reason)}")
      end
    end)
  end

  defp reinforce_rhizome_pathways(expectations) do
    Enum.each(expectations, fn {id, expectation} ->
      pathway =
        plasticity_pathway(expectation)
        |> Map.put(:weight_delta, reinforce_weight_delta(expectation))

      case rhizome_module().reinforce_pathway(pathway) do
        {:ok, _} -> :ok
        {:error, reason} -> Logger.warning("[StemCell] Failed to reinforce pathway for #{id}: #{inspect(reason)}")
      end
    end)
  end

  defp persist_execution_outcome(state, action, params, outcome) do
    payload =
      state
      |> execution_outcome_base(action, params)
      |> Map.merge(execution_outcome_payload(outcome))

    case memory_module().submit_execution_outcome(payload) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("[StemCell] Failed to persist execution outcome for #{action}: #{inspect(reason)}")
        :ok
    end
  end

  defp persist_prediction_error(payload) when is_map(payload) do
    case memory_module().submit_prediction_error(payload) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("[StemCell] Failed to persist prediction error for #{stateful_error_id(payload)}: #{inspect(reason)}")
        :ok
    end
  end

  defp execution_outcome_base(state, action, params) do
    cell_id = Map.get(state.dna_spec, "id", "unknown_cell")
    executor = executor_label(state.dna_spec)
    vm_id = extract_vm_id(params)

    %{
      "cell_id" => cell_id,
      "action" => action,
      "executor" => executor,
      "vm_id" => vm_id,
      "params" => normalize_execution_params(params),
      "belief_snapshot" => stringify_nested(state.beliefs),
      "recorded_at" => System.system_time(:second)
    }
  end

  defp execution_failure_payload(state, action, params, reason) do
    %{
      "id" => "prediction_error:#{state.lineage_id}:execution_failure:#{System.system_time(:second)}",
      "cell_id" => state.lineage_id,
      "source_cell_id" => state.lineage_id,
      "type" => "execution_failure",
      "message" => "execution failed for #{action}",
      "metadata" => %{
        "action" => action,
        "executor" => executor_label(state.dna_spec),
        "vm_id" => extract_vm_id(params),
        "reason" => inspect(reason),
        "event_source" => "execution",
        "expectation_lineage" => expectation_lineage(state.expectations)
      },
      "status" => "failure",
      "vfe" => 1.0,
      "atp" => state.atp_metabolism,
      "expectations" => stringify_nested(state.expectations),
      "expectation_lineage" => expectation_lineage(state.expectations)
    }
  end

  defp nociception_payload(state, prediction_error, metadata, vfe, utility_threshold, expectation_lineage) do
    %{
      "id" => "prediction_error:#{state.lineage_id}:#{prediction_error.type}:#{prediction_error.timestamp}",
      "cell_id" => state.lineage_id,
      "source_cell_id" => prediction_error.cell_id,
      "type" => prediction_error.type,
      "message" => prediction_error.message,
      "metadata" =>
        metadata
        |> Map.put_new("event_source", "nociception")
        |> Map.put("expectation_lineage", expectation_lineage)
        |> stringify_nested(),
      "status" => if(vfe > utility_threshold, do: "pruned", else: "observed"),
      "vfe" => vfe,
      "atp" => state.atp_metabolism,
      "expectations" => stringify_nested(state.expectations),
      "expectation_lineage" => expectation_lineage
    }
  end

  defp execution_outcome_payload({:ok, result}) when is_map(result) do
    %{
      "status" => "success",
      "exit_code" => result[:exit_code] || result["exit_code"],
      "result" => stringify_nested(result)
    }
  end

  defp execution_outcome_payload({:ok, result}) do
    %{
      "status" => "success",
      "exit_code" => 0,
      "result" => stringify_nested(result)
    }
  end

  defp execution_outcome_payload({:error, reason}) do
    %{
      "status" => "failure",
      "exit_code" => failure_exit_code(reason),
      "error" => stringify_nested(reason)
    }
  end

  defp failure_exit_code(reason) when is_integer(reason), do: reason
  defp failure_exit_code(_reason), do: -1

  defp extract_vm_id(params) when is_list(params), do: Keyword.get(params, :vm_id, "default_vm")
  defp extract_vm_id(params) when is_map(params), do: Map.get(params, :vm_id) || Map.get(params, "vm_id") || "default_vm"
  defp extract_vm_id(_params), do: "default_vm"

  defp normalize_execution_params(params) when is_list(params), do: params |> Enum.into(%{}) |> stringify_nested()
  defp normalize_execution_params(params) when is_map(params), do: stringify_nested(params)
  defp normalize_execution_params(other), do: %{"value" => stringify_nested(other)}

  defp memory_module do
    Application.get_env(:core, :memory_module, Rhizome.Memory)
  end

  defp rhizome_module do
    Application.get_env(:core, :rhizome_module, Rhizome.Native)
  end

  defp stateful_error_id(%{"id" => id}) when is_binary(id), do: id
  defp stateful_error_id(_payload), do: "prediction_error"

  defp executor_label(dna_spec) do
    case Map.get(dna_spec, "executor") do
      %{"module" => module_name, "function" => function_name} ->
        "#{module_name}.#{function_name}"

      %{module: module_name, function: function_name} ->
        "#{module_name}.#{function_name}"

      _ ->
        "none"
    end
  end

  defp checkpoint_state(state) do
    snapshot = state_snapshot(state)

    case memory_module().checkpoint_cell_state(snapshot) do
      {:ok, _} ->
        state

      {:error, reason} ->
        Logger.warning("[StemCell] Failed to checkpoint cell state for #{state.lineage_id}: #{inspect(reason)}")
        state
    end
  end

  defp state_snapshot(state) do
    %{
      "lineage_id" => state.lineage_id,
      "dna_path" => state.dna_path,
      "beliefs" => stringify_nested(state.beliefs),
      "expectations" => stringify_nested(state.expectations),
      "status" => to_string(state.status),
      "atp_metabolism" => state.atp_metabolism
    }
  end

  defp merge_recovered_state(state, recovered_state) do
    expectations =
      recovered_state
      |> Map.get("expectations", %{})
      |> normalize_expectations()

    beliefs =
      recovered_state
      |> Map.get("beliefs", %{})
      |> normalize_map()

    status =
      recovered_state
      |> Map.get("status", "active")
      |> normalize_status()

    atp_metabolism =
      recovered_state
      |> Map.get("atp_metabolism", 1.0)
      |> normalize_atp()

    %{state | expectations: expectations, beliefs: beliefs, status: status, atp_metabolism: atp_metabolism}
  end

  defp below_execution_budget?(state) do
    required = Core.DNA.atp_requirement(state.dna)
    state.atp_metabolism < required
  end

  defp normalize_expectations(expectations) when is_map(expectations) do
    Map.new(expectations, fn {key, value} ->
      expectation =
        case value do
          %{"goal" => goal} = map -> normalize_expectation_map(goal, map, key)
          %{goal: goal} = map -> normalize_expectation_map(goal, map, key)
          other -> default_expectation(key, other)
        end

      {key, expectation}
    end)
  end

  defp normalize_expectations(_), do: %{}

  defp normalize_map(value) when is_map(value), do: value
  defp normalize_map(_), do: %{}

  defp normalize_status(status) when status in [:active, :torpor, :revived, :shed, :terminated], do: status
  defp normalize_status("torpor"), do: :torpor
  defp normalize_status("revived"), do: :revived
  defp normalize_status("shed"), do: :shed
  defp normalize_status("terminated"), do: :terminated
  defp normalize_status(_), do: :active

  defp normalize_atp(value) when is_float(value), do: value
  defp normalize_atp(value) when is_integer(value), do: value * 1.0
  defp normalize_atp(_), do: 1.0

  defp normalize_precision(value) when is_float(value), do: value
  defp normalize_precision(value) when is_integer(value), do: value * 1.0
  defp normalize_precision(_), do: 1.0

  defp normalize_objective_weight(value) when is_float(value), do: value
  defp normalize_objective_weight(value) when is_integer(value), do: value * 1.0
  defp normalize_objective_weight(_), do: 1.0

  defp resolve_executor(dna_spec) do
    case Map.get(dna_spec, "executor") do
      spec when is_map(spec) -> {:ok, spec}
      _ -> {:error, :executor_not_configured}
    end
  end

  defp load_dna!(%Core.DNA{} = dna), do: dna
  defp load_dna!(dna_path) when is_binary(dna_path), do: Core.DNA.load!(dna_path)

  defp apply_lifecycle_transition(state, :high_pressure, metadata) do
    if Core.DNA.safety_critical?(state.dna) do
      state
      |> put_in([:beliefs, :last_lifecycle_transition], lifecycle_event("preserved", metadata))
      |> Map.put(:atp_metabolism, 0.2)
      |> Map.put(:status, :active)
    else
      essential = hd(state.synapses)
      others = tl(state.synapses)

      Enum.each(others, fn pid ->
        if Process.alive?(pid), do: GenServer.stop(pid)
      end)

      state
      |> put_in([:beliefs, :last_lifecycle_transition], lifecycle_event("torpor", metadata))
      |> Map.put(:atp_metabolism, 0.1)
      |> Map.put(:status, :torpor)
      |> Map.put(:synapses, [essential])
    end
  end

  defp apply_lifecycle_transition(state, :medium_pressure, metadata) do
    if Core.DNA.speculative?(state.dna) do
      Logger.warning("[StemCell] Medium Stress: Speculative Cell undergoing programmed apoptosis.")

      next_state =
        state
        |> put_in([:beliefs, :last_lifecycle_transition], lifecycle_event("shed", metadata))
        |> Map.put(:status, :shed)

      {:stop, :metabolic_pruning, next_state}
    else
      Logger.warning("[StemCell] Medium Metabolic Stress detected. Reducing activity.")

      state
      |> put_in([:beliefs, :last_lifecycle_transition], lifecycle_event("active", metadata))
      |> Map.put(:atp_metabolism, 0.5)
      |> Map.put(:status, :active)
    end
  end

  defp apply_lifecycle_transition(state, :low_pressure, metadata) do
    next_status =
      case state.status do
        :torpor -> :revived
        :revived -> :active
        :terminated -> :terminated
        _ -> :active
      end

    state
    |> put_in([:beliefs, :last_lifecycle_transition], lifecycle_event(to_string(next_status), metadata))
    |> Map.put(:atp_metabolism, 0.8)
    |> Map.put(:status, next_status)
  end

  defp apply_lifecycle_transition(state, :terminated, metadata) do
    state
    |> put_in([:beliefs, :last_lifecycle_transition], lifecycle_event("terminated", metadata))
    |> Map.put(:status, :terminated)
  end

  defp lifecycle_event(status, metadata) do
    %{
      "status" => status,
      "metadata" => metadata,
      "recorded_at" => System.system_time(:second)
    }
  end

  defp resolve_executor_target(executor_spec) do
    module_name = Map.get(executor_spec, "module") || Map.get(executor_spec, :module)
    function_name = Map.get(executor_spec, "function") || Map.get(executor_spec, :function)

    with {:ok, module} <- resolve_executor_module(module_name),
         {:ok, function} <- resolve_executor_function(function_name) do
      {:ok, module, function}
    end
  end

  defp resolve_executor_module(module_name) when is_binary(module_name) do
    module =
      module_name
      |> String.trim_leading("Elixir.")
      |> then(&"Elixir." <> &1)
      |> String.to_existing_atom()

    {:ok, module}
  rescue
    ArgumentError -> {:error, {:invalid_executor_module, module_name}}
  end

  defp resolve_executor_module(module_name), do: {:error, {:invalid_executor_module, module_name}}

  defp resolve_executor_function(function_name) when is_binary(function_name) do
    {:ok, String.to_atom(function_name)}
  end

  defp resolve_executor_function(function_name) when is_atom(function_name), do: {:ok, function_name}
  defp resolve_executor_function(function_name), do: {:error, {:invalid_executor_function, function_name}}

  defp invoke_executor(module, function, payload) do
    if function_exported?(module, function, 1) do
      apply(module, function, [payload])
    else
      {:error, {:invalid_executor_function, function}}
    end
  end

  defp executor_payload(dna_spec, action, params, executor_spec) do
    %{
      "action" => action,
      "cell_type" => Map.get(dna_spec, "cell_type"),
      "params" => normalize_execution_params(params),
      "default_args" => normalize_metadata_map(Map.get(executor_spec, "default_args") || Map.get(executor_spec, :default_args) || %{})
    }
  end

  defp build_expectation(id, goal, precision, attrs, state) do
    attrs = normalize_expectation_attrs(attrs)

    %{
      id: to_string(id),
      goal: goal,
      predicted_outcome: Map.get(attrs, "predicted_outcome", goal),
      precision: normalize_precision(precision),
      objective_weight: normalize_objective_weight(Map.get(attrs, "objective_weight", 1.0)),
      trace_id: Map.get(attrs, "trace_id", "expectation:#{state.lineage_id}:#{id}:#{System.unique_integer([:positive])}"),
      source_step_id: Map.get(attrs, "source_step_id", to_string(id)),
      source_attractor_id: Map.get(attrs, "source_attractor_id"),
      metadata: normalize_metadata_map(Map.get(attrs, "metadata", %{}))
    }
  end

  defp normalize_expectation_map(goal, map, key) do
    expectation_id = Map.get(map, "id") || Map.get(map, :id) || to_string(key)

    %{
      id: to_string(expectation_id),
      goal: goal,
      predicted_outcome: Map.get(map, "predicted_outcome") || Map.get(map, :predicted_outcome) || goal,
      precision: normalize_precision(Map.get(map, "precision") || Map.get(map, :precision)),
      objective_weight: normalize_objective_weight(Map.get(map, "objective_weight") || Map.get(map, :objective_weight) || 1.0),
      trace_id: Map.get(map, "trace_id") || Map.get(map, :trace_id) || "expectation:#{expectation_id}",
      source_step_id: Map.get(map, "source_step_id") || Map.get(map, :source_step_id) || to_string(key),
      source_attractor_id: Map.get(map, "source_attractor_id") || Map.get(map, :source_attractor_id),
      metadata: normalize_metadata_map(Map.get(map, "metadata") || Map.get(map, :metadata) || %{})
    }
  end

  defp default_expectation(key, goal) do
    %{
      id: to_string(key),
      goal: goal,
      predicted_outcome: goal,
      precision: 1.0,
      objective_weight: 1.0,
      trace_id: "expectation:#{key}",
      source_step_id: to_string(key),
      source_attractor_id: nil,
      metadata: %{}
    }
  end

  defp normalize_expectation_attrs(attrs) when is_map(attrs), do: normalize_metadata_map(attrs)
  defp normalize_expectation_attrs(attrs) when is_list(attrs), do: attrs |> Enum.into(%{}) |> normalize_metadata_map()
  defp normalize_expectation_attrs(_), do: %{}

  defp normalize_prediction_metadata(metadata), do: normalize_metadata_map(metadata)

  defp normalize_metadata_map(value) when is_map(value) do
    Map.new(value, fn {key, nested_value} ->
      normalized_value =
        case nested_value do
          map when is_map(map) -> normalize_metadata_map(map)
          list when is_list(list) -> Enum.map(list, &normalize_metadata_value/1)
          other -> normalize_metadata_value(other)
        end

      {to_string(key), normalized_value}
    end)
  end

  defp normalize_metadata_map(_), do: %{}

  defp normalize_metadata_value(value) when is_map(value), do: normalize_metadata_map(value)
  defp normalize_metadata_value(value) when is_list(value), do: Enum.map(value, &normalize_metadata_value/1)
  defp normalize_metadata_value(value), do: value

  defp prediction_error_signal(id, expectation, metadata) do
    explicit_errors = Map.get(metadata, "expectation_errors", %{})
    expectation_id = expectation.id || to_string(id)

    cond do
      is_map(explicit_errors) and Map.has_key?(explicit_errors, expectation_id) ->
        normalize_error_signal(Map.get(explicit_errors, expectation_id))

      Map.get(metadata, "failed_expectation_id") == expectation_id ->
        1.0

      Map.get(metadata, "trace_id") == expectation.trace_id ->
        1.0

      true ->
        normalize_error_signal(Map.get(metadata, "error_signal", severity_error_signal(Map.get(metadata, "severity"))))
    end
  end

  defp severity_error_signal("critical"), do: 1.0
  defp severity_error_signal("high"), do: 1.0
  defp severity_error_signal("medium"), do: 0.6
  defp severity_error_signal("low"), do: 0.3
  defp severity_error_signal(_), do: 1.0

  defp normalize_error_signal(value) when is_float(value), do: value
  defp normalize_error_signal(value) when is_integer(value), do: value * 1.0
  defp normalize_error_signal(value) when is_binary(value) do
    case Float.parse(value) do
      {parsed, _} -> parsed
      :error -> severity_error_signal(value)
    end
  end

  defp normalize_error_signal(_), do: 1.0

  defp expectation_lineage(expectations) do
    expectations
    |> Enum.map(fn {id, expectation} ->
      %{
        "id" => expectation.id || to_string(id),
        "goal" => stringify_nested(expectation.goal),
        "predicted_outcome" => stringify_nested(expectation.predicted_outcome),
        "precision" => expectation.precision,
        "objective_weight" => expectation.objective_weight,
        "trace_id" => expectation.trace_id,
        "source_step_id" => expectation.source_step_id,
        "source_attractor_id" => expectation.source_attractor_id,
        "metadata" => stringify_nested(expectation.metadata)
      }
    end)
  end

  defp plasticity_pathway(expectation) do
    %{
      from_id: expectation.source_step_id || expectation.id,
      to_id: expectation.source_attractor_id || expectation.id,
      relationship_type: "PREDICTS",
      trace_id: expectation.trace_id || "plasticity",
      source_step_id: expectation.source_step_id || expectation.id,
      target_id: expectation.source_attractor_id || expectation.id
    }
  end

  defp reinforce_weight_delta(expectation) do
    expectation.precision * expectation.objective_weight
  end

  defp prune_weight_delta(expectation) do
    expectation.precision * expectation.objective_weight
  end

  defp stringify_nested(value) when is_map(value) do
    Map.new(value, fn {key, nested} -> {to_string(key), stringify_nested(nested)} end)
  end

  defp stringify_nested(value) when is_list(value), do: Enum.map(value, &stringify_nested/1)
  defp stringify_nested(value) when is_atom(value), do: Atom.to_string(value)
  defp stringify_nested(value), do: value
end
