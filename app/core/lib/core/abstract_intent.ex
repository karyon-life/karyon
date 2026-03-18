defmodule Core.AbstractIntent do
  @moduledoc """
  Abstract-intent ingestion and drift detection for Chapter 12.
  """

  @schema "karyon.abstract-intent.v1"

  def ingest_sources(source_paths, opts \\ [])

  def ingest_sources(source_paths, opts) when is_list(source_paths) and is_list(opts) do
    with {:ok, documents} <- load_documents(source_paths),
         {:ok, directives} <- extract_directives(documents),
         {:ok, git_history} <- git_history(opts),
         observed_signals <- observed_signals(opts),
         drift_events <- detect_drift(directives, observed_signals),
         bundle <- build_bundle(documents, directives, git_history, observed_signals, drift_events),
         {:ok, _} <- memory_module(opts).submit_abstract_intent_event(bundle) do
      {:ok, bundle}
    end
  end

  def ingest_sources(_source_paths, _opts), do: {:error, :invalid_abstract_intent_sources}

  defp load_documents(paths) do
    paths
    |> Enum.map(&Path.expand/1)
    |> Enum.uniq()
    |> Enum.reduce_while({:ok, []}, fn path, {:ok, acc} ->
      case File.read(path) do
        {:ok, body} ->
          {:cont,
           {:ok,
            [
              %{
                "document_id" => document_id(path),
                "source_path" => path,
                "headline" => headline(body, path),
                "body" => body
              }
              | acc
            ]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, documents} when documents != [] -> {:ok, Enum.reverse(documents)}
      {:ok, []} -> {:error, :no_abstract_intent_sources}
      error -> error
    end
  end

  defp extract_directives(documents) do
    directives =
      documents
      |> Enum.flat_map(fn document ->
        document["body"]
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&directive_line?/1)
        |> Enum.map(fn line ->
          %{
            "directive_id" => directive_id(document["document_id"], line),
            "document_id" => document["document_id"],
            "source_path" => document["source_path"],
            "headline" => document["headline"],
            "statement" => normalize_statement(line),
            "constraint_kind" => constraint_kind(line),
            "expected_signal" => expected_signal(line)
          }
        end)
      end)

    {:ok, directives}
  end

  defp git_history(opts) do
    case Keyword.get(opts, :git_history) do
      history when is_list(history) ->
        {:ok, Enum.map(history, &normalize_git_history_entry/1)}

      nil ->
        git_module = Keyword.get(opts, :git_module, __MODULE__.Git)
        git_module.recent_history()

      _other ->
        {:error, :invalid_git_history}
    end
  end

  defp build_bundle(documents, directives, git_history, observed_signals, drift_events) do
    %{
      "intent_bundle_id" => "abstract_intent:#{System.system_time(:second)}",
      "schema" => @schema,
      "source_documents" => documents,
      "directives" => directives,
      "git_history" => git_history,
      "observed_signals" => observed_signals,
      "drift_events" => drift_events,
      "recorded_at" => System.system_time(:second)
    }
  end

  defp detect_drift(directives, observed_signals) do
    Enum.reduce(directives, [], fn directive, acc ->
      signal = directive["expected_signal"]

      case Map.fetch(observed_signals, signal) do
        {:ok, true} ->
          acc

        {:ok, false} ->
          [
            %{
              "drift_id" => "implementation_drift:#{directive["directive_id"]}",
              "directive_id" => directive["directive_id"],
              "expected_signal" => signal,
              "document_id" => directive["document_id"],
              "drift_kind" => "design_implementation_documentation",
              "severity" => "high",
              "message" => "Observed implementation state does not satisfy #{signal}.",
              "recorded_at" => System.system_time(:second)
            }
            | acc
          ]

        :error ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp observed_signals(opts) do
    Keyword.get_lazy(opts, :observed_signals, fn ->
      %{
        "engine_workspace_boundary" => Code.ensure_loaded?(Sandbox.MonorepoPipeline),
        "execution_telemetry" => Code.ensure_loaded?(Core.ExecutionTelemetry),
        "teacher_daemon" => Code.ensure_loaded?(Core.TeacherDaemon),
        "objective_manifest" => Code.ensure_loaded?(Core.ObjectiveManifest)
      }
    end)
  end

  defp memory_module(opts) do
    Keyword.get(opts, :memory_module, Application.get_env(:core, :memory_module, Rhizome.Memory))
  end

  defp directive_line?(line) do
    normalized = String.downcase(line)

    line != "" and
      not String.starts_with?(line, ["---", "#", "*", "```"]) and
      (String.contains?(normalized, "must") or
         String.contains?(normalized, "treated as") or
         String.contains?(normalized, "refuses") or
         String.contains?(normalized, "should"))
  end

  defp normalize_statement(line) do
    line
    |> String.trim_leading("- ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp constraint_kind(line) do
    normalized = String.downcase(line)

    cond do
      String.contains?(normalized, "read-only") -> "boundary"
      String.contains?(normalized, "telemetry") -> "telemetry"
      String.contains?(normalized, "teacher daemon") -> "curriculum"
      String.contains?(normalized, "objective") -> "objective"
      true -> "architecture"
    end
  end

  defp expected_signal(line) do
    normalized = String.downcase(line)

    cond do
      String.contains?(normalized, "read-only") or String.contains?(normalized, "engine workspace") ->
        "engine_workspace_boundary"

      String.contains?(normalized, "telemetry") ->
        "execution_telemetry"

      String.contains?(normalized, "teacher daemon") ->
        "teacher_daemon"

      String.contains?(normalized, "objective") or String.contains?(normalized, "attractor") ->
        "objective_manifest"

      true ->
        "engine_workspace_boundary"
    end
  end

  defp document_id(path), do: "intent_document:#{:erlang.phash2(path)}"
  defp directive_id(document_id, line), do: "intent_directive:#{:erlang.phash2({document_id, line})}"

  defp headline(body, path) do
    case Regex.run(~r/^#+\s+(.+)$/m, body, capture: :all_but_first) do
      [title] -> String.trim(title)
      _ -> Path.basename(path)
    end
  end

  defp normalize_git_history_entry(%{"sha" => _, "timestamp" => _, "subject" => _} = entry), do: entry
  defp normalize_git_history_entry(%{sha: sha, timestamp: timestamp, subject: subject}), do: %{"sha" => sha, "timestamp" => timestamp, "subject" => subject}

  defp normalize_git_history_entry(entry) when is_binary(entry) do
    case String.split(entry, " ", parts: 3) do
      [sha, timestamp, subject] -> %{"sha" => sha, "timestamp" => timestamp, "subject" => subject}
      _ -> %{"sha" => "unknown", "timestamp" => "0", "subject" => entry}
    end
  end

  defmodule Git do
    def recent_history do
      case System.cmd("git", ["log", "--format=%H %ct %s", "-n", "12", "--", ".", ":(exclude)app/_build"], stderr_to_stdout: true) do
        {output, 0} ->
          {:ok,
           output
           |> String.split("\n", trim: true)
           |> Enum.map(fn line ->
             case String.split(line, " ", parts: 3) do
               [sha, timestamp, subject] ->
                 %{"sha" => sha, "timestamp" => timestamp, "subject" => subject}

               _ ->
                 %{"sha" => "unknown", "timestamp" => "0", "subject" => line}
             end
           end)}

        {_output, _code} ->
          {:ok, []}
      end
    end
  end
end
