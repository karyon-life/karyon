defmodule Core.TeacherDaemon do
  @moduledoc """
  Synthetic-oracle curriculum generation and bounded exam administration.
  """

  alias Core.ExecutionTelemetry

  @schema "karyon.teacher-daemon.v1"
  @default_executor Sandbox.Executor

  def generate_exams(source_paths, opts \\ [])

  def generate_exams(source_paths, opts) when is_list(source_paths) do
    max_exams = Keyword.get(opts, :max_exams, 5)
    threshold = Keyword.get(opts, :confidence_threshold, 0.7)

    source_paths
    |> Enum.map(&Path.expand/1)
    |> Enum.filter(&File.regular?/1)
    |> Enum.sort()
    |> Enum.reduce_while({:ok, []}, fn path, {:ok, acc} ->
      case build_exam(path, threshold) do
        {:ok, exam} ->
          updated = [exam | acc]

          if length(updated) >= max_exams do
            {:halt, {:ok, Enum.reverse(updated)}}
          else
            {:cont, {:ok, updated}}
          end

        {:error, :empty_curriculum_source} ->
          {:cont, {:ok, acc}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  def generate_exams(_sources, _opts), do: {:error, :invalid_curriculum_sources}

  def administer_exam(exam, opts \\ [])

  def administer_exam(exam, opts) when is_map(exam) do
    executor = Keyword.get(opts, :executor_module, @default_executor)
    memory_module = Keyword.get(opts, :memory_module, Application.get_env(:core, :memory_module, Rhizome.Memory))
    workspace_root = Keyword.get(opts, :workspace_root, Path.join(System.tmp_dir!(), "karyon-teacher-daemon"))
    vm_id = Keyword.get(opts, :vm_id, "teacher-daemon-vm")

    with :ok <- validate_exam(exam),
         intent <- execution_intent(exam, workspace_root),
         {:ok, result} <- executor.execute_plan(intent),
         {:ok, event} <- teacher_event(exam, intent, result, vm_id),
         {:ok, _} <- memory_module.submit_teacher_daemon_event(event),
         {:ok, _} <- memory_module.submit_execution_telemetry(teacher_execution_telemetry(exam, intent, result)) do
      {:ok, %{exam: exam, intent: intent, result: result, teacher_event: event}}
    end
  end

  def administer_exam(_exam, _opts), do: {:error, :invalid_teacher_exam}

  defp build_exam(path, confidence_threshold) do
    case File.read(path) do
      {:ok, body} ->
        prompt =
          body
          |> String.split(~r/\n\s*\n/, trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "---")))
          |> List.first()

        if is_nil(prompt) do
          {:error, :empty_curriculum_source}
        else
          exam = %{
            "exam_id" => exam_id(path),
            "schema" => @schema,
            "source_path" => path,
            "source_kind" => source_kind(path),
            "headline" => headline(body, path),
            "prompt" => normalize_prompt(prompt),
            "confidence_threshold" => confidence_threshold,
            "curriculum_scope" => curriculum_scope(path),
            "recorded_at" => System.system_time(:second)
          }

          {:ok, exam}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_exam(%{
         "exam_id" => exam_id,
         "schema" => @schema,
         "source_path" => source_path,
         "headline" => headline,
         "prompt" => prompt
       })
       when is_binary(exam_id) and exam_id != "" and is_binary(source_path) and source_path != "" and
              is_binary(headline) and headline != "" and is_binary(prompt) and prompt != "" do
    :ok
  end

  defp validate_exam(_exam), do: {:error, :invalid_teacher_exam}

  defp execution_intent(exam, workspace_root) do
    %{
      "id" => "intent:teacher-daemon:#{exam["exam_id"]}",
      "action" => "execute_plan",
      "plan_attractor_id" => "teacher-daemon-attractor",
      "plan_step_ids" => ["teacher-step:#{exam["exam_id"]}"],
      "executor" => %{"module" => "Sandbox.Executor", "function" => "execute_plan"},
      "transition_delta" => %{
        "workspace_root" => Path.expand(workspace_root),
        "metabolism_admission" => %{"status" => "admitted", "lane" => "curriculum", "pressure" => "medium"}
      },
      "params" => %{
        "attractor" => "teacher-daemon-attractor",
        "steps" => [
          %{
            "id" => "teacher-step:#{exam["exam_id"]}",
            "action" => "validate_curriculum_requirement",
            "params" => %{
              "source_path" => exam["source_path"],
              "headline" => exam["headline"],
              "prompt" => exam["prompt"],
              "curriculum_scope" => exam["curriculum_scope"]
            }
          }
        ]
      }
    }
  end

  defp teacher_event(exam, intent, result, vm_id) do
    event = %{
      "teacher_event_id" => "teacher_event:#{exam["exam_id"]}",
      "exam_id" => exam["exam_id"],
      "schema" => @schema,
      "source_path" => exam["source_path"],
      "source_kind" => exam["source_kind"],
      "headline" => exam["headline"],
      "prompt" => exam["prompt"],
      "confidence_threshold" => exam["confidence_threshold"],
      "curriculum_scope" => exam["curriculum_scope"],
      "intent_id" => intent["id"],
      "outcome_status" => normalize_outcome_status(result),
      "vm_id" => Map.get(result, :vm_id) || Map.get(result, "vm_id") || vm_id,
      "performance_trace" => %{
        "telemetry" => stringify_nested(Map.get(result, :telemetry) || Map.get(result, "telemetry") || %{}),
        "audit" => stringify_nested(Map.get(result, :audit) || Map.get(result, "audit") || %{})
      },
      "recorded_at" => System.system_time(:second)
    }

    {:ok, event}
  end

  defp teacher_execution_telemetry(exam, intent, result) do
    ExecutionTelemetry.from_execution_outcome(%{
      "id" => "execution_outcome:teacher-daemon:#{exam["exam_id"]}",
      "cell_id" => "teacher_daemon",
      "action" => "execute_plan",
      "status" => normalize_outcome_status(result),
      "executor" => "Sandbox.Executor.execute_plan",
      "vm_id" => Map.get(result, :vm_id) || Map.get(result, "vm_id") || "teacher-daemon-vm",
      "exit_code" => Map.get(result, :exit_code) || Map.get(result, "exit_code") || 0,
      "learning_phase" => "action_feedback",
      "learning_edge" => "action_feedback->plasticity",
      "execution_intent_id" => intent["id"],
      "plan_attractor_id" => intent["plan_attractor_id"],
      "plan_step_ids" => intent["plan_step_ids"],
      "result" =>
        %{
          "summary" => summarize_teacher_result(result),
          "telemetry" => stringify_nested(Map.get(result, :telemetry) || Map.get(result, "telemetry") || %{}),
          "audit" => stringify_nested(Map.get(result, :audit) || Map.get(result, "audit") || %{}),
          "prompt" => exam["prompt"]
        }
    })
  end

  defp summarize_teacher_result(result) do
    telemetry = Map.get(result, :telemetry) || Map.get(result, "telemetry") || %{}
    summary = Map.get(telemetry, :summary) || Map.get(telemetry, "summary") || %{}

    %{
      "mutation_count" => Map.get(summary, :mutation_count) || Map.get(summary, "mutation_count") || 0,
      "compile_count" => Map.get(summary, :compile_count) || Map.get(summary, "compile_count") || 0,
      "tests_ran" => Map.get(summary, :tests_ran) || Map.get(summary, "tests_ran") || 0,
      "tests_failed" => Map.get(summary, :tests_failed) || Map.get(summary, "tests_failed") || 0
    }
  end

  defp normalize_outcome_status(result) do
    case Map.get(result, :status) || Map.get(result, "status") do
      :exited -> "success"
      "exited" -> "success"
      "success" -> "success"
      other when is_binary(other) -> other
      _ -> "success"
    end
  end

  defp source_kind(path) do
    case Path.extname(path) do
      ".md" -> "docs"
      ".yml" -> "spec"
      ".yaml" -> "spec"
      _ -> "text"
    end
  end

  defp curriculum_scope(path) do
    cond do
      String.contains?(path, "/docs/") -> "architectural_docs"
      String.ends_with?(path, "SPEC.md") -> "specification"
      true -> "curriculum_source"
    end
  end

  defp headline(body, path) do
    case Regex.run(~r/^#+\s+(.+)$/m, body, capture: :all_but_first) do
      [title] -> String.trim(title)
      _ -> Path.basename(path)
    end
  end

  defp normalize_prompt(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.slice(0, 240)
  end

  defp exam_id(path), do: "teacher_exam:#{:erlang.phash2(path)}"

  defp stringify_nested(value) when is_map(value), do: Map.new(value, fn {k, v} -> {to_string(k), stringify_nested(v)} end)
  defp stringify_nested(value) when is_list(value), do: Enum.map(value, &stringify_nested/1)
  defp stringify_nested(value), do: value
end
