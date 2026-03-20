defmodule Core.EnvironmentMembrane do
  @moduledoc """
  Explicit operator-environment membrane contract for engine-versus-target
  workspace boundaries.
  """

  @schema "karyon.operator-environment.v1"
  @engine_root Path.expand("../../..", __DIR__)
  @umbrella_root Path.expand("../..", __DIR__)

  def schema, do: @schema
  def engine_root, do: @engine_root
  def umbrella_root, do: @umbrella_root

  def target_root do
    Application.get_env(:core, :target_workspaces_root, Path.join(System.user_home!(), ".karyon/workspaces"))
    |> Path.expand()
  end

  def validate_target_workspace(path, opts \\ [])

  def validate_target_workspace(path, opts) when is_binary(path) and path != "" do
    workspace = Path.expand(path)
    engine = Keyword.get(opts, :engine_root, engine_root()) |> Path.expand()

    cond do
      workspace == engine -> {:error, :engine_workspace_forbidden}
      within?(workspace, engine) -> {:error, :engine_workspace_forbidden}
      true -> {:ok, workspace}
    end
  end

  def validate_target_workspace(_path, _opts), do: {:error, :invalid_target_workspace}

  def workspace_role(path, opts \\ []) do
    case validate_target_workspace(path, opts) do
      {:ok, _workspace} -> :target_workspace
      {:error, :engine_workspace_forbidden} -> :engine_workspace
      _ -> :unknown
    end
  end

  def target_workspace_from_intent(%{"transition_delta" => transition_delta} = intent) when is_map(transition_delta) do
    Map.get(transition_delta, "workspace_root") ||
      Map.get(transition_delta, :workspace_root) ||
      target_workspace_from_params(intent)
  end

  def target_workspace_from_intent(intent), do: target_workspace_from_params(intent)

  def environment_manifest do
    %{
      "schema" => @schema,
      "engine_root" => engine_root(),
      "umbrella_root" => umbrella_root(),
      "target_workspaces_root" => target_root()
    }
  end

  defp target_workspace_from_params(%{"params" => params}) when is_map(params) do
    Map.get(params, "target_workspace_root") ||
      Map.get(params, :target_workspace_root) ||
      Map.get(params, "workspace_root") ||
      Map.get(params, :workspace_root)
  end

  defp target_workspace_from_params(_intent), do: nil

  defp within?(path, root) do
    case Path.relative_to(path, root) do
      "." -> true
      relative when is_binary(relative) -> not String.starts_with?(relative, "..") and Path.type(relative) != :absolute
      _ -> false
    end
  end
end
