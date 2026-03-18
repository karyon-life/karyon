defmodule Sensory.Eyes do
  @moduledoc """
  Deterministic repository perception pipeline for the Eyes organ.
  """

  alias Sensory.Native
  alias Sensory.Perimeter

  @supported_extensions %{
    ".c" => "c",
    ".h" => "c",
    ".js" => "javascript",
    ".jsx" => "javascript",
    ".mjs" => "javascript",
    ".py" => "python",
    ".ts" => "javascript",
    ".tsx" => "javascript",
    ".ex" => "elixir",
    ".exs" => "elixir"
  }

  def parse_repository(path, opts \\ []) do
    with {:ok, _policy} <-
           Perimeter.validate_ingestion(%{
             organ: :eyes,
             surface: :repository_snapshot,
             transport: :filesystem
           }),
         {:ok, repo_path} <- validate_repository(path),
         {:ok, files} <- collect_repository_files(repo_path),
         {:ok, parsed_files} <- parse_files(files, Keyword.put(opts, :repo_path, repo_path)) do
      repo = %{
        repo_id: repository_id(repo_path),
        root_path: repo_path,
        file_count: length(parsed_files),
        files: parsed_files
      }

      {:ok, repo}
    end
  end

  def project_repository(path, opts \\ []) do
    with {:ok, repository} <- parse_repository(path, opts),
         :ok <- persist_repository(repository, opts) do
      {:ok, repository}
    end
  end

  defp validate_repository(path) when is_binary(path) do
    expanded = Path.expand(path)

    cond do
      not File.exists?(expanded) -> {:error, :repository_not_found}
      not File.dir?(expanded) -> {:error, :repository_not_directory}
      true -> {:ok, expanded}
    end
  end

  defp validate_repository(_path), do: {:error, :invalid_repository_path}

  defp collect_repository_files(repo_path) do
    files =
      repo_path
      |> Path.join("**/*")
      |> Path.wildcard(match_dot: false)
      |> Enum.filter(&File.regular?/1)
      |> Enum.filter(&(language_for_path(&1) != nil))
      |> Enum.sort()

    {:ok, files}
  end

  defp parse_files(files, opts) do
    native_module = Keyword.get(opts, :native_module, Native)
    repo_path = Keyword.fetch!(opts, :repo_path)

    Enum.reduce_while(files, {:ok, []}, fn file_path, {:ok, acc} ->
      language = language_for_path(file_path)
      code = File.read!(file_path)
      relative_path = relative_path(file_path, repo_path)

      case native_module.parse_to_graph(language, code) do
        json when is_binary(json) ->
          case Jason.decode(json) do
            {:ok, %{"nodes" => nodes, "edges" => edges} = graph} when is_list(nodes) and is_list(edges) ->
              parsed_file = %{
                file_id: file_id(relative_path),
                path: relative_path,
                absolute_path: file_path,
                language: language,
                node_count: length(nodes),
                edge_count: length(edges),
                graph: graph
              }

              {:cont, {:ok, [parsed_file | acc]}}

            {:ok, _other} ->
              {:halt, {:error, {:invalid_graph_projection, relative_path}}}

            {:error, reason} ->
              {:halt, {:error, {:invalid_graph_json, relative_path, reason}}}
          end

        "Unsupported language" ->
          {:cont, {:ok, acc}}

        other ->
          {:halt, {:error, {:unsupported_parse_result, relative_path, other}}}
      end
    end)
    |> case do
      {:ok, parsed_files} -> {:ok, Enum.reverse(parsed_files)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp persist_repository(repository, opts) do
    memory_module = Keyword.get(opts, :memory_module, Application.get_env(:sensory, :memory_module, Rhizome.Memory))

    with {:ok, _repo} <-
           memory_module.upsert_graph_node(%{
             label: "Repository",
             id: repository.repo_id,
             properties: %{
               root_path: repository.root_path,
               file_count: repository.file_count,
               organ: "eyes"
             }
           }) do
      Enum.reduce_while(repository.files, :ok, fn file, :ok ->
        with {:ok, _file_node} <-
               memory_module.upsert_graph_node(%{
                 label: "RepositoryFile",
                 id: file.file_id,
                 properties: %{
                   path: file.path,
                   language: file.language,
                   node_count: file.node_count,
                   edge_count: file.edge_count
                 }
               }),
             {:ok, _contains} <-
               memory_module.relate_graph_nodes(%{
                 from: %{label: "Repository", id: repository.repo_id},
                 to: %{label: "RepositoryFile", id: file.file_id},
                 relationship_type: "CONTAINS_FILE"
               }),
             {:ok, _ast} <-
               memory_module.upsert_graph_node(%{
                 label: "AstProjection",
                 id: "ast_projection:" <> file.file_id,
                 properties: %{
                   file_id: file.file_id,
                   language: file.language,
                   node_count: file.node_count,
                   edge_count: file.edge_count
                 }
               }),
             {:ok, _parsed} <-
               memory_module.relate_graph_nodes(%{
                 from: %{label: "RepositoryFile", id: file.file_id},
                 to: %{label: "AstProjection", id: "ast_projection:" <> file.file_id},
                 relationship_type: "PARSED_AS"
               }) do
          {:cont, :ok}
        else
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  defp relative_path(file_path, root_path) do
    file_path
    |> Path.relative_to(root_path)
    |> String.replace("\\", "/")
  end

  defp repository_id(repo_path), do: "repository:" <> repo_path
  defp file_id(relative_path), do: "repository_file:" <> relative_path

  defp language_for_path(path) do
    path
    |> Path.extname()
    |> then(&Map.get(@supported_extensions, &1))
  end
end
