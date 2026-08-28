defmodule JidoCode.Product.RepositoryWikiSurfaceContract do
  @moduledoc "Closed repository wiki product views and stable collection routes."

  @views [
    %{id: "overview", label: "Overview", icon: "hero-home", page_slug: "overview"},
    %{id: "guides", label: "Guides", icon: "hero-book-open", page_slug: "user-guides"},
    %{
      id: "architecture",
      label: "Architecture",
      icon: "hero-cube-transparent",
      page_slug: "architecture-index"
    },
    %{id: "project", label: "Project", icon: "hero-code-bracket", page_slug: "project"},
    %{
      id: "dependencies",
      label: "Dependencies",
      icon: "hero-circle-stack",
      page_slug: "dependency-overview"
    },
    %{id: "source", label: "Source", icon: "hero-command-line", page_slug: "source-map"},
    %{id: "search", label: "Search", icon: "hero-magnifying-glass", page_slug: nil},
    %{id: "history", label: "History", icon: "hero-clock", page_slug: nil},
    %{id: "gaps", label: "Known gaps", icon: "hero-exclamation-triangle", page_slug: nil},
    %{id: "usage", label: "Usage & cost", icon: "hero-banknotes", page_slug: nil},
    %{id: "operations", label: "Operations", icon: "hero-signal", page_slug: nil},
    %{id: "settings", label: "Settings", icon: "hero-cog-6-tooth", page_slug: nil}
  ]
  @ids Enum.map(@views, & &1.id)
  @slug ~r/^[a-z0-9][a-z0-9-]{0,159}$/u

  @spec all() :: [map()]
  def all, do: @views

  @spec fetch(String.t() | nil) :: map()
  def fetch(id) when id in @ids, do: Enum.find(@views, &(&1.id == id))
  def fetch(_id), do: hd(@views)

  @spec page_slug(String.t() | nil, map()) :: String.t() | nil
  def page_slug(value, view) when is_binary(value) and is_map(view) do
    if Regex.match?(@slug, value), do: value, else: view.page_slug
  end

  def page_slug(_value, view), do: view.page_slug

  @spec search_query(String.t() | nil) :: String.t()
  def search_query(value) when is_binary(value) do
    value = value |> String.normalize(:nfkc) |> String.trim()

    if byte_size(value) <= 80 and Regex.match?(~r/^[\p{L}\p{N}_\-\s]*$/u, value),
      do: value,
      else: ""
  end

  def search_query(_value), do: ""
end
