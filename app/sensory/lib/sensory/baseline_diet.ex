defmodule Sensory.BaselineDiet do
  @moduledoc """
  Deterministic baseline-diet ingestion for Chapter 12.

  The baseline diet turns a curated repository snapshot into a typed curriculum
  artifact with explicit acceptance criteria before higher-order action loops
  are allowed to dominate.
  """

  alias Sensory.Eyes

  @default_criteria %{
    min_files: 1,
    min_languages: 1,
    min_total_nodes: 1
  }

  def ingest_repository(path, opts \\ []) do
    with {:ok, repository} <- Eyes.project_repository(path, opts),
         {:ok, baseline} <- build_baseline(repository, opts),
         :ok <- persist_baseline(baseline, opts) do
      {:ok, baseline}
    end
  end

  def acceptance_criteria(opts \\ []) do
    opts
    |> Keyword.get(:acceptance_criteria, %{})
    |> normalize_criteria()
  end

  defp build_baseline(repository, opts) do
    criteria = acceptance_criteria(opts)
    languages = repository.files |> Enum.map(& &1.language) |> Enum.uniq() |> Enum.sort()
    total_nodes = Enum.reduce(repository.files, 0, &(&1.node_count + &2))
    total_edges = Enum.reduce(repository.files, 0, &(&1.edge_count + &2))

    acceptance = %{
      "status" => acceptance_status(repository, languages, total_nodes, criteria),
      "criteria" => %{
        "min_files" => criteria.min_files,
        "min_languages" => criteria.min_languages,
        "min_total_nodes" => criteria.min_total_nodes
      }
    }

    baseline = %{
      "baseline_id" => baseline_id(repository.repo_id),
      "repository_id" => repository.repo_id,
      "root_path" => repository.root_path,
      "file_count" => repository.file_count,
      "language_count" => length(languages),
      "languages" => languages,
      "total_nodes" => total_nodes,
      "total_edges" => total_edges,
      "sample_files" => Enum.map(repository.files, & &1.path),
      "acceptance" => acceptance,
      "ingested_at" => System.system_time(:second)
    }

    if acceptance["status"] == "accepted" do
      {:ok, baseline}
    else
      {:error, {:baseline_diet_rejected, baseline}}
    end
  end

  defp persist_baseline(baseline, opts) do
    memory_module =
      Keyword.get(opts, :memory_module, Application.get_env(:sensory, :memory_module, Rhizome.Memory))

    case memory_module.submit_baseline_curriculum(baseline) do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp acceptance_status(repository, languages, total_nodes, criteria) do
    cond do
      repository.file_count < criteria.min_files -> "rejected"
      length(languages) < criteria.min_languages -> "rejected"
      total_nodes < criteria.min_total_nodes -> "rejected"
      true -> "accepted"
    end
  end

  defp normalize_criteria(criteria) when is_map(criteria) do
    %{
      min_files: positive_integer(Map.get(criteria, :min_files) || Map.get(criteria, "min_files") || @default_criteria.min_files),
      min_languages:
        positive_integer(Map.get(criteria, :min_languages) || Map.get(criteria, "min_languages") || @default_criteria.min_languages),
      min_total_nodes:
        positive_integer(Map.get(criteria, :min_total_nodes) || Map.get(criteria, "min_total_nodes") || @default_criteria.min_total_nodes)
    }
  end

  defp normalize_criteria(_criteria), do: @default_criteria

  defp positive_integer(value) when is_integer(value) and value > 0, do: value
  defp positive_integer(_value), do: 1

  defp baseline_id(repository_id), do: "baseline_curriculum:#{:erlang.phash2(repository_id)}"
end
