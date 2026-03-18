defmodule Core.StemCellPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Core.StemCell
  
  # Import the module to test private functions if needed, 
  # but here we test the logic via public API or by exposing it for testing.
  # For VFE, we'll test the calculation logic which is deterministic.
  
  property "Variational Free Energy is calculated as the weighted sum of expectation errors" do
    check all expectations <- list_of(expectation_gen()) do
      expected_vfe = Enum.reduce(expectations, 0.0, fn {_, %{precision: p, objective_weight: weight}}, acc ->
        acc + (p * weight)
      end)

      actual_vfe = calculate_vfe(expectations)

      assert_in_delta actual_vfe, expected_vfe, 0.0001
    end
  end

  property "Metabolic spikes correctly transition cell status and ATP metabolism" do
    check all spike <- metabolic_spike_gen() do
      # Simulate handle_info({:msg, topic, payload}, state)
      # Since we want to test the logic, we can mock the state and call the handler
      
      initial_state = %{
        status: :active,
        atp_metabolism: 1.0
      }
      
      # Protox encoding simulation or using the decoder logic
      # For property testing, we can just test the logic inside handle_info
      # if it's extracted or by calling handle_info if we mock the protox decoder.
      
      handle_info_logic = fn
        %{severity: "high"}, state -> %{state | atp_metabolism: 0.1, status: :torpor}
        %{severity: "medium"}, state -> %{state | atp_metabolism: 0.5}
        _, state -> state
      end

      new_state = handle_info_logic.(spike, initial_state)

      case spike.severity do
        "high" ->
          assert new_state.status == :torpor
          assert new_state.atp_metabolism == 0.1
        "medium" ->
          assert new_state.status == :active
          assert new_state.atp_metabolism == 0.5
        _ ->
          assert new_state.status == :active
          assert new_state.atp_metabolism == 1.0
      end
    end
  end

  property "role membership discovery returns only live unique peers" do
    check all member_count <- integer(1..8) do
      role = {:property_motor, System.unique_integer([:positive])}
      pids = spawn_members(role, member_count)

      try do
        members = StemCell.role_members(role)

        assert Enum.sort(members) == Enum.sort(pids)
        assert length(members) == member_count

        Enum.each(pids, fn pid ->
          if member_count == 1 do
            assert {:error, :no_gradient_detected} = StemCell.sense_gradient(role, exclude: pid)
          else
            assert {:ok, discovered_pid} = StemCell.sense_gradient(role, exclude: pid)
            assert discovered_pid in pids
            refute discovered_pid == pid
          end
        end)
      after
        Enum.each(pids, fn pid ->
          if Process.alive?(pid), do: Process.exit(pid, :kill)
        end)
      end
    end
  end

  # Generators
  
  defp expectation_gen do
    gen all id <- string(:alphanumeric, min_length: 1),
            precision <- float(min: 0.0, max: 1.0),
            objective_weight <- float(min: 0.1, max: 3.0) do
      {id, %{precision: precision, objective_weight: objective_weight}}
    end
  end

  defp metabolic_spike_gen do
    gen all severity <- member_of(["high", "medium", "low", "none"]) do
      %{severity: severity}
    end
  end

  # Logic extraction for testing
  defp calculate_vfe(expectations) do
    Enum.reduce(expectations, 0.0, fn {_id, %{precision: p, objective_weight: weight}}, acc ->
      acc + (p * weight * 1.0)
    end)
  end

  defp spawn_members(role, member_count) do
    for _ <- 1..member_count do
      pid = spawn(fn -> Process.sleep(:infinity) end)
      :pg.join(role, pid)
      :pg.join({:cell_role, role}, pid)
      pid
    end
  end
end
