defmodule Core.ExecutionTelemetry do
  @moduledoc """
  Typed execution-telemetry curriculum surface for Chapter 12.
  """

  @schema "karyon.execution-telemetry.v1"

  def from_execution_outcome(outcome) when is_map(outcome) do
    document = stringify_keys(outcome)
    result = Map.get(document, "result", %{})
    tags = telemetry_tags(document, result)

    %{
      "telemetry_id" => telemetry_id(document),
      "schema" => @schema,
      "source_document_id" => execution_source_id(document),
      "cell_id" => Map.get(document, "cell_id", "unknown_cell"),
      "action" => Map.get(document, "action", "unknown_action"),
      "status" => Map.get(document, "status", "unknown"),
      "executor" => Map.get(document, "executor", "unknown_executor"),
      "vm_id" => Map.get(document, "vm_id", "default_vm"),
      "exit_code" => normalize_exit_code(Map.get(document, "exit_code", 0)),
      "learning_phase" => Map.get(document, "learning_phase", "action_feedback"),
      "learning_edge" => Map.get(document, "learning_edge", "action_feedback->plasticity"),
      "plan_attractor_id" => Map.get(document, "plan_attractor_id"),
      "plan_step_ids" => List.wrap(Map.get(document, "plan_step_ids", [])),
      "tags" => tags,
      "provenance" => %{
        "source" => "execution_outcome",
        "execution_intent_id" => Map.get(document, "execution_intent_id"),
        "execution_intent" => Map.get(document, "execution_intent", %{}),
        "recorded_at" => Map.get(document, "recorded_at", System.system_time(:second))
      },
      "result_summary" => telemetry_summary(result),
      "result" => stringify_nested(result)
    }
  end

  def replay_recent(opts \\ []) do
    memory_module = Keyword.get(opts, :memory_module, Application.get_env(:core, :memory_module, Rhizome.Memory))
    limit = Keyword.get(opts, :limit, 10)

    case memory_module.query_recent_execution_telemetry(%{limit: limit}) do
      {:ok, rows} ->
        {:ok,
         Enum.map(rows, fn row ->
           row
           |> stringify_keys()
           |> Map.put_new("schema", @schema)
         end)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp telemetry_id(document) do
    source_id = execution_source_id(document)
    "execution_telemetry:#{:erlang.phash2(source_id)}"
  end

  defp execution_source_id(%{"id" => id}) when is_binary(id) and id != "", do: id

  defp execution_source_id(document) do
    cell_id = Map.get(document, "cell_id", "unknown_cell")
    action = Map.get(document, "action", "unknown_action")
    recorded_at = Map.get(document, "recorded_at", System.system_time(:second))
    "execution_outcome:#{cell_id}:#{action}:#{recorded_at}"
  end

  defp telemetry_tags(document, result) do
    base_tags =
      [
        "status:#{Map.get(document, "status", "unknown")}",
        "action:#{Map.get(document, "action", "unknown_action")}",
        "executor:#{Map.get(document, "executor", "unknown_executor")}",
        "vm:#{Map.get(document, "vm_id", "default_vm")}"
      ]

    summary = telemetry_summary(result)

    extra_tags =
      []
      |> maybe_tag("tests_present", summary["tests_ran"] > 0)
      |> maybe_tag("compilation_recorded", summary["compile_count"] > 0)
      |> maybe_tag("mutations_recorded", summary["mutation_count"] > 0)

    base_tags ++ extra_tags
  end

  defp telemetry_summary(result) when is_map(result) do
    summary = Map.get(result, "summary", %{}) |> stringify_keys()

    %{
      "stdout_present" => present?(Map.get(result, "stdout")),
      "stderr_present" => present?(Map.get(result, "stderr")),
      "mutation_count" => normalize_integer(Map.get(summary, "mutation_count", 0)),
      "compile_count" => normalize_integer(Map.get(summary, "compile_count", 0)),
      "tests_ran" => normalize_integer(Map.get(summary, "tests_ran", 0)),
      "tests_failed" => normalize_integer(Map.get(summary, "tests_failed", 0))
    }
  end

  defp telemetry_summary(_result) do
    %{
      "stdout_present" => false,
      "stderr_present" => false,
      "mutation_count" => 0,
      "compile_count" => 0,
      "tests_ran" => 0,
      "tests_failed" => 0
    }
  end

  defp present?(value) when is_binary(value), do: value != ""
  defp present?(value) when is_list(value), do: value != []
  defp present?(nil), do: false
  defp present?(_), do: true

  defp normalize_integer(value) when is_integer(value), do: value
  defp normalize_integer(value) when is_float(value), do: trunc(value)
  defp normalize_integer(_), do: 0

  defp normalize_exit_code(value) when is_integer(value), do: value
  defp normalize_exit_code(_), do: 0

  defp maybe_tag(tags, _tag, false), do: tags
  defp maybe_tag(tags, tag, true), do: tags ++ [tag]

  defp stringify_keys(map) when is_map(map), do: Map.new(map, fn {k, v} -> {to_string(k), stringify_nested(v)} end)
  defp stringify_keys(_), do: %{}

  defp stringify_nested(value) when is_map(value), do: stringify_keys(value)
  defp stringify_nested(value) when is_list(value), do: Enum.map(value, &stringify_nested/1)
  defp stringify_nested(value), do: value
end
