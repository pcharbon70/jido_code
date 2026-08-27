defmodule JidoCode.Factory.RepositoryWiki.MetadataCache do
  @moduledoc "Disposable repository-scoped cache for observed dependency metadata."

  use Agent

  alias JidoCode.Knowledge

  @profile "wiki-metadata-cache/1.0.0"

  @type key :: {String.t(), String.t(), atom(), String.t(), String.t(), String.t()}

  @spec profile() :: map()
  def profile do
    value = %{
      revision: @profile,
      backend: :disposable_agent,
      persistence: :none,
      scope: [:tenant, :repository, :authorization_class, :package, :version, :request_profile]
    }

    Map.put(value, :digest, Knowledge.repository_wiki_digest(value))
  end

  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(options \\ []) when is_list(options) do
    Agent.start_link(fn -> %{} end, Keyword.take(options, [:name]))
  end

  @spec lookup(Agent.agent(), key(), DateTime.t()) :: :miss | {:fresh | :stale, map()}
  def lookup(cache, key, %DateTime{} = now) do
    Agent.get_and_update(cache, fn entries ->
      case entries[key] do
        %{expires_at: expires_at} = entry ->
          cond do
            DateTime.compare(now, expires_at) in [:lt, :eq] ->
              {{:fresh, entry}, entries}

            DateTime.compare(now, entry.stale_until) in [:lt, :eq] ->
              {{:stale, entry}, entries}

            true ->
              {:miss, Map.delete(entries, key)}
          end

        nil ->
          {:miss, entries}
      end
    end)
  catch
    :exit, _reason -> :miss
  end

  @spec put(Agent.agent(), key(), map(), :positive | :negative, DateTime.t(), map()) :: :ok
  def put(cache, key, value, outcome, %DateTime{} = now, policy)
      when outcome in [:positive, :negative] and is_map(value) and is_map(policy) do
    ttl =
      if outcome == :positive, do: policy.positive_ttl_seconds, else: policy.negative_ttl_seconds

    entry = %{
      value: value,
      outcome: outcome,
      stored_at: now,
      expires_at: DateTime.add(now, ttl, :second),
      stale_until: DateTime.add(now, ttl + policy.stale_if_error_seconds, :second)
    }

    Agent.update(cache, &Map.put(&1, key, entry))
  catch
    :exit, _reason -> :ok
  end

  @spec size(Agent.agent()) :: non_neg_integer()
  def size(cache) do
    Agent.get(cache, &map_size/1)
  catch
    :exit, _reason -> 0
  end
end
