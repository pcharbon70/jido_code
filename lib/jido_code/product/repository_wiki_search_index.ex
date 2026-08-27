defmodule JidoCode.Product.RepositoryWikiSearchIndex do
  @moduledoc """
  Disposable deterministic search projection for one authorized wiki edition.

  The caller must authorize and retrieve candidate pages before construction.
  The index is an in-memory value with no persistence or acceptance authority.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.ResourceIdentity

  @profile "wiki-search-projection/1.0.0"
  @maximums %{
    pages: 3_072,
    query_bytes: 80,
    query_tokens: 8,
    result_limit: 20,
    tokens_per_page: 64
  }
  @token ~r/[\p{L}\p{N}_-]+/u
  @query ~r/^[\p{L}\p{N}_\-\s]+$/u
  @slug ~r/^[a-z0-9][a-z0-9-]{0,159}$/u
  @kind ~r/^[a-z][a-z0-9_]{0,95}$/u
  @audiences ~w[user developer operator contributor reference architecture policy unknown]

  @spec profile() :: map()
  def profile do
    value = %{
      revision: @profile,
      limits: @maximums,
      tokenizer: :unicode_letters_numbers_nfkc_casefold,
      ranking: :exact_weighted_fields,
      candidate_policy: :authorized_before_indexing,
      durable_authority: false
    }

    Map.put(value, :digest, Contract.digest(value))
  end

  @spec build(String.t(), non_neg_integer(), [map()]) :: {:ok, map()} | {:error, Error.t()}
  def build(edition_iri, dataset_revision, pages)
      when is_integer(dataset_revision) and dataset_revision >= 0 and is_list(pages) do
    with :ok <- ResourceIdentity.validate(edition_iri),
         true <- length(pages) <= @maximums.pages,
         {:ok, documents} <- documents(edition_iri, pages) do
      value = %{
        profile: @profile,
        profile_digest: profile().digest,
        edition_iri: edition_iri,
        dataset_revision: dataset_revision,
        documents: documents,
        document_count: length(documents),
        durable_authority?: false
      }

      {:ok, Map.put(value, :digest, Contract.digest(value))}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_search_build)
    end
  end

  def build(_edition, _revision, _pages), do: invalid(:repository_wiki_search_build)

  @spec search(map(), String.t(), pos_integer()) :: {:ok, [map()]} | {:error, Error.t()}
  def search(index, query, limit \\ 10)

  def search(index, query, limit)
      when is_map(index) and is_binary(query) and is_integer(limit) and limit > 0 do
    with true <- index[:profile] == @profile and exact_digest?(index, :digest),
         true <- limit <= @maximums.result_limit,
         {:ok, query_tokens} <- query_tokens(query) do
      results =
        index.documents
        |> Enum.map(&rank(&1, query_tokens))
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(&{-&1.score, &1.order, &1.slug})
        |> Enum.take(limit)

      {:ok, results}
    else
      _invalid -> invalid(:repository_wiki_search)
    end
  end

  def search(_index, _query, _limit), do: invalid(:repository_wiki_search)

  defp documents(edition_iri, pages) do
    pages
    |> Enum.reduce_while({:ok, []}, fn page, {:ok, result} ->
      case document(edition_iri, page) do
        {:ok, value} -> {:cont, {:ok, [value | result]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.sort_by(values, &{&1.order, &1.slug})}
      error -> error
    end
  end

  defp document(edition_iri, page) do
    with :ok <- ResourceIdentity.validate(page[:page_iri]),
         true <- String.starts_with?(page.page_iri, edition_iri <> "/page/"),
         true <- bounded?(page[:slug], 160),
         true <- Regex.match?(@slug, page.slug),
         true <- bounded?(page[:title], 256),
         true <- bounded?(page[:kind], 96),
         true <- Regex.match?(@kind, page.kind),
         true <- bounded?(page[:audience], 32),
         true <- page.audience in @audiences,
         true <- is_integer(page[:order]) and page.order >= 0 do
      fields = %{
        title: tokens(page.title),
        slug: tokens(page.slug),
        kind: tokens(page.kind),
        audience: tokens(page.audience)
      }

      if Enum.all?(fields, fn {_field, values} -> length(values) <= @maximums.tokens_per_page end) do
        {:ok,
         %{
           page_iri: page.page_iri,
           slug: page.slug,
           title: page.title,
           kind: page.kind,
           audience: page.audience,
           order: page.order,
           fields: fields
         }}
      else
        invalid(:repository_wiki_search_document)
      end
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_search_document)
    end
  end

  defp query_tokens(query) do
    normalized = query |> String.normalize(:nfkc) |> String.trim()

    cond do
      normalized == "" ->
        {:ok, []}

      byte_size(normalized) > @maximums.query_bytes ->
        invalid(:repository_wiki_search_query)

      not Regex.match?(@query, normalized) ->
        invalid(:repository_wiki_search_query)

      true ->
        values = tokens(normalized) |> Enum.uniq()

        if length(values) <= @maximums.query_tokens,
          do: {:ok, values},
          else: invalid(:repository_wiki_search_query)
    end
  end

  defp rank(_document, []), do: nil

  defp rank(document, query_tokens) do
    score =
      Enum.reduce(query_tokens, 0, fn token, total ->
        total +
          field_score(document.fields.title, token, 8) +
          field_score(document.fields.slug, token, 4) +
          field_score(document.fields.kind, token, 2) +
          field_score(document.fields.audience, token, 2)
      end)

    matched =
      Enum.count(query_tokens, fn token ->
        Enum.any?(Map.values(document.fields), &(token in &1))
      end)

    if score > 0 and matched == length(query_tokens) do
      %{
        page_iri: document.page_iri,
        slug: document.slug,
        title: document.title,
        audience: document.audience,
        kind: document.kind,
        order: document.order,
        score: score,
        snippet: "#{document.title} · #{document.audience} · #{document.kind}"
      }
    end
  end

  defp field_score(values, token, weight), do: if(token in values, do: weight, else: 0)

  defp tokens(value) do
    @token
    |> Regex.scan(value |> String.normalize(:nfkc) |> String.downcase())
    |> List.flatten()
    |> Enum.map(&String.slice(&1, 0, 48))
  end

  defp bounded?(value, maximum),
    do: is_binary(value) and byte_size(value) in 1..maximum and String.valid?(value)

  defp exact_digest?(value, key) do
    Contract.digest?(value[key]) and Contract.digest(Map.delete(value, key)) == value[key]
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
