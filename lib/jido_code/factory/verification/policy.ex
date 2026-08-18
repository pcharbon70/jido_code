defmodule JidoCode.Factory.Verification.Policy do
  @moduledoc "Fixed path, command, and flake policy for one verifier revision."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @enforce_keys [
    :revision,
    :allowed_path_prefixes,
    :protected_path_prefixes,
    :max_patch_bytes,
    :evaluator_capability_iri,
    :required_check_classes,
    :checks,
    :flake_policy
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @classes ~w[
    formatting compilation static_analysis type_check regression issue hidden security
    candidate_test
  ]a
  @owners ~w[verifier candidate]a
  @statuses ~w[failed timeout]a
  @digest ~r/^[a-f0-9]{64}$/

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with true <- text?(attributes[:revision], 256),
         {:ok, allowed} <- paths(attributes[:allowed_path_prefixes]),
         {:ok, protected} <- paths(attributes[:protected_path_prefixes]),
         true <- Enum.all?(protected, &inside_any?(&1, allowed)),
         bytes when is_integer(bytes) and bytes in 1..100_000_000 <-
           attributes[:max_patch_bytes],
         :ok <- resource(attributes[:evaluator_capability_iri]),
         {:ok, required} <- required_classes(attributes[:required_check_classes]),
         {:ok, checks} <- checks(attributes[:checks]),
         true <- required_checks?(checks, required),
         true <- independent_checks?(checks),
         {:ok, flake_policy} <- flake_policy(attributes[:flake_policy]) do
      {:ok,
       %__MODULE__{
         revision: attributes.revision,
         allowed_path_prefixes: allowed,
         protected_path_prefixes: protected,
         max_patch_bytes: bytes,
         evaluator_capability_iri: attributes.evaluator_capability_iri,
         required_check_classes: required,
         checks: checks,
         flake_policy: flake_policy
       }}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:verification_policy)
    end
  rescue
    _error -> invalid(:verification_policy)
  end

  def new(_attributes), do: invalid(:verification_policy)

  @spec authorize_paths(t(), [String.t()]) :: :ok | {:error, AdapterError.t()}
  def authorize_paths(%__MODULE__{} = policy, changed_paths) when is_list(changed_paths) do
    cond do
      changed_paths == [] ->
        invalid(:verification_changed_paths)

      not Enum.all?(
        changed_paths,
        &(valid_path?(&1) and inside_any?(&1, policy.allowed_path_prefixes))
      ) ->
        unauthorized(:verification_changed_paths)

      Enum.any?(changed_paths, &inside_any?(&1, policy.protected_path_prefixes)) ->
        unauthorized(:verification_protected_path)

      true ->
        :ok
    end
  end

  def authorize_paths(_policy, _changed_paths), do: invalid(:verification_changed_paths)

  defp checks(values) when is_list(values) and values != [] and length(values) <= 100 do
    decoded = Enum.map(values, &check/1)

    if Enum.all?(decoded, &match?({:ok, _check}, &1)) do
      checks = decoded |> Enum.map(&elem(&1, 1)) |> Enum.sort_by(& &1.id)

      if checks |> Enum.map(& &1.id) |> Enum.uniq() |> length() == length(checks),
        do: {:ok, checks},
        else: invalid(:verification_checks)
    else
      invalid(:verification_checks)
    end
  end

  defp checks(_values), do: invalid(:verification_checks)

  defp check(
         %{
           id: id,
           class: class,
           owner: owner,
           mandatory?: mandatory?,
           command_digest: command_digest
         } = check
       )
       when class in @classes and owner in @owners and is_boolean(mandatory?) do
    requirement_iri = Map.get(check, :requirement_iri)

    with true <- text?(id, 160),
         true <- is_binary(command_digest) and Regex.match?(@digest, command_digest),
         :ok <- check_owner(class, owner, requirement_iri) do
      {:ok,
       %{
         id: id,
         class: class,
         owner: owner,
         mandatory?: mandatory?,
         command_digest: command_digest,
         requirement_iri: requirement_iri
       }}
    else
      _invalid -> invalid(:verification_check)
    end
  end

  defp check(_check), do: invalid(:verification_check)

  defp check_owner(:candidate_test, :candidate, requirement_iri), do: resource(requirement_iri)

  defp check_owner(class, :verifier, nil) when class != :candidate_test,
    do: :ok

  defp check_owner(_class, _owner, _requirement_iri), do: invalid(:verification_check_owner)

  defp required_classes(values) when is_list(values) and values != [] do
    values = values |> Enum.uniq() |> Enum.sort()

    if Enum.all?(values, &(&1 in @classes and &1 != :candidate_test)),
      do: {:ok, values},
      else: invalid(:verification_required_checks)
  end

  defp required_classes(_values), do: invalid(:verification_required_checks)

  defp required_checks?(checks, required) do
    present = checks |> Enum.filter(& &1.mandatory?) |> Enum.map(& &1.class) |> MapSet.new()
    MapSet.subset?(MapSet.new(required), present)
  end

  defp independent_checks?(checks), do: Enum.any?(checks, &(&1.owner == :verifier))

  defp flake_policy(%{eligible_statuses: statuses, max_reruns: max_reruns})
       when is_list(statuses) and max_reruns in 0..3 do
    statuses = statuses |> Enum.uniq() |> Enum.sort()

    if Enum.all?(statuses, &(&1 in @statuses)),
      do: {:ok, %{eligible_statuses: statuses, max_reruns: max_reruns}},
      else: invalid(:verification_flake_policy)
  end

  defp flake_policy(_policy), do: invalid(:verification_flake_policy)

  defp paths(values) when is_list(values) and values != [] and length(values) <= 100 do
    values = values |> Enum.uniq() |> Enum.sort()
    if Enum.all?(values, &valid_path?/1), do: {:ok, values}, else: invalid(:verification_paths)
  end

  defp paths(_values), do: invalid(:verification_paths)

  defp valid_path?(path) when is_binary(path) and byte_size(path) in 1..512 do
    Path.type(path) == :relative and not String.contains?(path, ["\\", <<0>>, "//"]) and
      not String.starts_with?(path, ["./", "/"]) and path == Path.join(Path.split(path)) and
      Enum.all?(Path.split(path), &(&1 not in [".", "..", ""]))
  end

  defp valid_path?(_path), do: false

  defp inside_any?(path, prefixes), do: Enum.any?(prefixes, &inside?(path, &1))

  defp inside?(path, prefix) do
    relative = Path.relative_to(path, prefix)

    relative == "." or
      (Path.type(relative) == :relative and relative != ".." and
         not String.starts_with?(relative, "../"))
  end

  defp resource(value) do
    if Knowledge.validate_resource_identity(value) == :ok,
      do: :ok,
      else: invalid(:verification_policy_resource)
  end

  defp text?(value, maximum) when is_binary(value),
    do: byte_size(value) in 1..maximum and not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)

  defp text?(_value, _maximum), do: false
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp unauthorized(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
end
