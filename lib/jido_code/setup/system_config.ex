defmodule JidoCode.Setup.SystemConfig do
  @moduledoc """
  Minimal onboarding state loader used by the root route gate.
  """

  @enforce_keys [:onboarding_completed, :onboarding_step]
  defstruct onboarding_completed: false, onboarding_step: 1

  @type t :: %__MODULE__{
          onboarding_completed: boolean(),
          onboarding_step: pos_integer()
        }

  @type load_error :: %{
          diagnostic: String.t(),
          detail: term(),
          onboarding_step: pos_integer()
        }

  @spec load() :: {:ok, t()} | {:error, load_error()}
  def load do
    with {:ok, raw_config} <- run_loader(),
         {:ok, config} <- normalize_config(raw_config) do
      {:ok, config}
    else
      {:error, reason} -> {:error, load_error(reason)}
    end
  end

  @doc false
  def default_loader do
    {:ok, Application.get_env(:jido_code, :system_config, %{})}
  end

  defp run_loader do
    loader = Application.get_env(:jido_code, :system_config_loader, &__MODULE__.default_loader/0)

    if is_function(loader, 0) do
      safe_invoke_loader(loader)
    else
      {:error, :invalid_loader}
    end
  end

  defp safe_invoke_loader(loader) do
    try do
      case loader.() do
        {:ok, _config} = result ->
          result

        {:error, _reason} = result ->
          result

        other ->
          {:error, {:invalid_loader_result, other}}
      end
    rescue
      exception ->
        {:error, {:loader_exception, Exception.message(exception)}}
    catch
      kind, reason ->
        {:error, {:loader_throw, {kind, reason}}}
    end
  end

  defp normalize_config(%__MODULE__{} = config), do: validate_config(config)

  defp normalize_config(config) when is_map(config) do
    validate_config(%__MODULE__{
      onboarding_completed: map_get(config, :onboarding_completed, "onboarding_completed", false),
      onboarding_step: map_get(config, :onboarding_step, "onboarding_step", 1)
    })
  end

  defp normalize_config(other), do: {:error, {:invalid_config, other}}

  defp validate_config(%__MODULE__{onboarding_completed: completed, onboarding_step: step} = config)
       when is_boolean(completed) and is_integer(step) and step > 0 do
    {:ok, config}
  end

  defp validate_config(%__MODULE__{} = config), do: {:error, {:invalid_config, config}}

  defp map_get(map, atom_key, string_key, default) do
    cond do
      Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
      Map.has_key?(map, string_key) -> Map.get(map, string_key)
      true -> default
    end
  end

  defp load_error(reason) do
    %{
      onboarding_step: 1,
      detail: reason,
      diagnostic:
        "Unable to load SystemConfig. Continue setup from step 1 and verify configuration storage (#{format_reason(reason)})."
    }
  end

  defp format_reason(reason), do: inspect(reason)
end
