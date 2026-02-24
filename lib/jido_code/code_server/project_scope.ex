defmodule JidoCode.CodeServer.ProjectScope do
  @moduledoc """
  Resolves project scope required by the `JidoCode.CodeServer` facade.
  """

  alias JidoCode.CodeServer.Error
  alias JidoCode.Projects.Project

  @project_not_found_remediation """
  Open Workbench, select an imported project, and retry the conversation action.
  """

  @workspace_unavailable_remediation """
  Complete project import and local workspace setup so an absolute workspace path is available.
  """

  @workspace_environment_unsupported_remediation """
  Switch the project workspace environment to local and rerun baseline sync before starting a conversation.
  """

  @type scope :: %{
          project_id: String.t(),
          root_path: String.t(),
          project: map()
        }

  @spec resolve(term()) :: {:ok, scope()} | {:error, Error.typed_error()}
  def resolve(project_id) do
    with {:ok, normalized_project_id} <- normalize_project_id(project_id),
         {:ok, project} <- fetch_project(normalized_project_id),
         {:ok, root_path} <- resolve_workspace_root(project, normalized_project_id) do
      {:ok, %{project_id: normalized_project_id, root_path: root_path, project: project}}
    end
  end

  defp normalize_project_id(project_id) do
    case normalize_optional_string(project_id) do
      nil ->
        {:error,
         Error.build(
           "code_server_project_not_found",
           "Project identifier is missing.",
           @project_not_found_remediation
         )}

      normalized_project_id ->
        {:ok, normalized_project_id}
    end
  end

  defp fetch_project(project_id) do
    case Project.read(query: [filter: [id: project_id], limit: 1]) do
      {:ok, [project | _rest]} ->
        {:ok, project}

      {:ok, []} ->
        {:error,
         Error.build(
           "code_server_project_not_found",
           "Project #{project_id} was not found.",
           @project_not_found_remediation,
           project_id: project_id
         )}

      {:error, reason} ->
        {:error,
         Error.build(
           "code_server_project_not_found",
           "Project lookup failed (#{format_reason(reason)}).",
           @project_not_found_remediation,
           project_id: project_id
         )}
    end
  end

  defp resolve_workspace_root(project, project_id) when is_map(project) do
    settings =
      project
      |> map_get(:settings, "settings", %{})
      |> normalize_map()

    workspace_settings =
      settings
      |> map_get(:workspace, "workspace", %{})
      |> normalize_map()

    case normalize_workspace_environment(
           map_get(workspace_settings, :workspace_environment, "workspace_environment", nil)
         ) do
      :local ->
        workspace_settings
        |> map_get(:workspace_path, "workspace_path", nil)
        |> validate_workspace_path(project_id)

      :sprite ->
        {:error,
         Error.build(
           "code_server_workspace_environment_unsupported",
           "Project workspace environment is sprite/cloud and cannot run local conversations.",
           @workspace_environment_unsupported_remediation,
           project_id: project_id
         )}

      :unknown ->
        {:error,
         Error.build(
           "code_server_workspace_environment_unsupported",
           "Project workspace environment is unavailable or unsupported.",
           @workspace_environment_unsupported_remediation,
           project_id: project_id
         )}
    end
  end

  defp resolve_workspace_root(_project, project_id) do
    {:error,
     Error.build(
       "code_server_workspace_unavailable",
       "Project settings are unavailable for workspace resolution.",
       @workspace_unavailable_remediation,
       project_id: project_id
     )}
  end

  defp validate_workspace_path(path, project_id) do
    normalized_path = normalize_optional_string(path)

    cond do
      is_nil(normalized_path) ->
        {:error,
         Error.build(
           "code_server_workspace_unavailable",
           "Local workspace path is missing from project settings.",
           @workspace_unavailable_remediation,
           project_id: project_id
         )}

      Path.type(normalized_path) != :absolute ->
        {:error,
         Error.build(
           "code_server_workspace_unavailable",
           "Workspace path must be absolute: #{normalized_path}.",
           @workspace_unavailable_remediation,
           project_id: project_id
         )}

      not File.dir?(normalized_path) ->
        {:error,
         Error.build(
           "code_server_workspace_unavailable",
           "Workspace path does not exist on disk: #{normalized_path}.",
           @workspace_unavailable_remediation,
           project_id: project_id
         )}

      true ->
        {:ok, normalized_path}
    end
  end

  defp normalize_workspace_environment(:local), do: :local
  defp normalize_workspace_environment("local"), do: :local
  defp normalize_workspace_environment(:sprite), do: :sprite
  defp normalize_workspace_environment("sprite"), do: :sprite
  defp normalize_workspace_environment(:cloud), do: :sprite
  defp normalize_workspace_environment("cloud"), do: :sprite
  defp normalize_workspace_environment(_other), do: :unknown

  defp format_reason(reason) do
    Exception.message(reason)
  rescue
    _exception -> inspect(reason)
  end

  defp normalize_optional_string(nil), do: nil
  defp normalize_optional_string(value) when is_boolean(value), do: nil

  defp normalize_optional_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      normalized_value -> normalized_value
    end
  end

  defp normalize_optional_string(value) when is_atom(value),
    do: value |> Atom.to_string() |> normalize_optional_string()

  defp normalize_optional_string(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_optional_string(value) when is_float(value), do: :erlang.float_to_binary(value)
  defp normalize_optional_string(_value), do: nil

  defp normalize_map(value) when is_map(value), do: value
  defp normalize_map(_value), do: %{}

  defp map_get(map, atom_key, string_key, default)

  defp map_get(map, atom_key, string_key, default) when is_map(map) do
    cond do
      Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
      Map.has_key?(map, string_key) -> Map.get(map, string_key)
      true -> default
    end
  end

  defp map_get(_map, _atom_key, _string_key, default), do: default
end
