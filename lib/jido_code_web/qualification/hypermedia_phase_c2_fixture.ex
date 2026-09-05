defmodule JidoCodeWeb.Qualification.HypermediaPhaseC2Fixture do
  @moduledoc """
  Deterministic presentation data for the compile-gated HUI-C2 composition.

  The fixture owns no lookup or effect boundary. It supplies closed, bounded
  display maps to exercise the application and projection component contracts.
  """

  @states [
    :ready,
    :empty,
    :stale,
    :incomplete,
    :contradicted,
    :truncated,
    :unauthorized,
    :unavailable,
    :maintenance,
    :recovery
  ]
  @protected_states [:unauthorized, :unavailable, :maintenance, :recovery]
  @hostile "<script id=\"hui-c2-hostile-script\">alert('unsafe')</script><img src=x onerror=alert(1)>"
  @protected_value "PROTECTED-ROW-MUST-CLEAR"
  @omitted_destination "Hidden administration destination"
  @page_count 3
  @filter_states ~w(ready stale empty)
  @sort_columns ~w(project health)
  @sort_directions ~w(ascending descending)
  @densities ~w(comfortable compact)
  @modes ~w(summary details)

  @doc "Returns the closed, server-shaped qualification composition."
  @spec composition() :: map()
  @spec composition(map()) :: map()
  def composition(params \\ %{})

  def composition(params) when is_map(params) and not is_struct(params) do
    selection = normalize_selection(params)
    project_form = Phoenix.Component.to_form(%{"view" => "c2"})

    filter_form =
      Phoenix.Component.to_form(%{
        "q" => selection.query,
        "state" => selection.state,
        "view" => "c2"
      })

    primitive_form =
      Phoenix.Component.to_form(%{
        "catalog_label" => selection.catalog_label,
        "density" => selection.density,
        "include_archived" => to_string(selection.include_archived),
        "mode" => selection.mode,
        "qualified_label" => selection.qualified_label,
        "view" => "c2"
      })

    %{
      states: @states,
      protected_states: @protected_states,
      protected_value: @protected_value,
      omitted_destination: @omitted_destination,
      hostile_content: @hostile,
      long_content: String.duplicate("Long localized qualification label — ", 24),
      native_selection: selection,
      project_form: project_form,
      filter_form: filter_form,
      primitive_form: primitive_form,
      brand: %{
        label: "JidoCode",
        href: "/__qualification/hypermedia?view=c2",
        service_label: "Read-only component qualification"
      },
      primary_navigation: [
        %{
          key: "overview",
          label: "Overview",
          href: "/__qualification/hypermedia?view=c2",
          current: true
        },
        %{
          key: "states",
          label: "Projection states",
          href: "#hui-c2-state-matrix"
        },
        %{
          key: "catalog",
          label: "Primitive catalog",
          href: "#hui-c2-primitive-catalog"
        }
      ],
      utility_navigation: [
        %{key: "native", label: "Native forms", href: "#hui-c2-native-forms"},
        %{key: "overlays", label: "Overlays", href: "#hui-c2-overlays"}
      ],
      compact_navigation: [
        %{
          key: "overview",
          label: "Overview",
          href: "/__qualification/hypermedia?view=c2",
          current: true
        },
        %{key: "states", label: "Projection states", href: "#hui-c2-state-matrix"},
        %{key: "catalog", label: "Primitive catalog", href: "#hui-c2-primitive-catalog"},
        %{key: "overlays", label: "Overlays", href: "#hui-c2-overlays"}
      ],
      project_options: [
        %{key: "c2", value: "c2", label: "HUI-C2 component composition"}
      ],
      breadcrumbs: [
        %{
          key: "qualification",
          label: "Qualification",
          href: "/__qualification/hypermedia",
          current: false
        },
        %{key: "phase-c2", label: "Milestone C · Phase 2", current: true}
      ],
      context: %{
        route_label: "Compile-gated fixture",
        scope_label: "Deterministic presentation data",
        role_label: "Qualification observer",
        assurance_label: "Local-only build gate",
        readiness: :limited,
        readiness_label: "Evidence candidate",
        explanation:
          "The server supplied this display-ready composition. Navigation visibility grants nothing."
      },
      attempt_context: %{
        label: "Component system integration",
        reference: "HUI-C2",
        scope_label: "Milestone C · phase 2",
        state: :running,
        state_label: "Evidence in progress"
      },
      account: %{display_name: "Ada Qualification", session_label: "Fixture session"},
      account_actions: [
        %{key: "baseline", label: "Open native baseline", href: "/__qualification/hypermedia"},
        %{key: "catalog", label: "Jump to catalog", href: "#hui-c2-primitive-catalog"}
      ],
      page_actions: [
        %{key: "states", label: "Inspect state matrix", href: "#hui-c2-state-matrix"},
        %{key: "forms", label: "Inspect native forms", href: "#hui-c2-native-forms"}
      ],
      filters: [
        %{
          key: "state",
          label: "Projection state",
          help: "Native presentation filter",
          field: filter_form[:state],
          options: [
            %{key: "ready", value: "ready", label: "Ready"},
            %{key: "stale", value: "stale", label: "Stale"},
            %{key: "empty", value: "empty", label: "Empty"}
          ]
        },
        %{
          key: "view",
          label: "Qualification view",
          help: "Keeps the closed C2 composition selected",
          field: filter_form[:view],
          options: [%{key: "c2", value: "c2", label: "HUI-C2"}]
        }
      ],
      pages: pages(selection),
      application_previous: pagination_link(selection, selection.page - 1, "Previous"),
      application_next: pagination_link(selection, selection.page + 1, "Next"),
      application_page_summary:
        "Showing qualification composition page #{selection.page} of #{@page_count}",
      errors: [
        %{
          key: "query",
          label: "Review the intentionally hostile search fixture",
          target_id: "hui-c2-filter-search-query"
        },
        %{
          key: "state",
          label: "Choose one supported state",
          target_id: "hui-c2-filter-search-filter-state"
        }
      ],
      attention_items: attention_items(),
      health_items: health_items(),
      fleet_rows: fleet_rows(selection),
      fleet_sort_hrefs: sort_hrefs(selection),
      fleet_previous_href: page_href(selection, selection.page - 1),
      fleet_next_href: page_href(selection, selection.page + 1),
      fleet_page_summary: "Qualification fleet page #{selection.page} of #{@page_count}",
      protected_rows: [
        %{
          project: @protected_value,
          project_href: "/__qualification/protected-target",
          work: @protected_value,
          agent: @protected_value,
          stage: @protected_value,
          health: @protected_value,
          health_state: :ready,
          freshness: @protected_value
        }
      ],
      attempt: attempt(),
      footer_metadata: [
        %{key: "candidate", label: "Candidate", value: "HUI-C2"},
        %{key: "mode", label: "Mode", value: "Qualification only"}
      ],
      footer_links: [
        %{key: "top", label: "Back to top", href: "#hui-c2-qualification"},
        %{key: "baseline", label: "Native baseline", href: "/__qualification/hypermedia"}
      ]
    }
  end

  def composition(_params), do: composition(%{})

  defp attention_items do
    Enum.map(1..25, fn index ->
      %{
        severity: if(index == 1, do: :critical, else: :medium),
        title: if(index == 1, do: @hostile, else: "Bounded attention item #{index}"),
        reason: "Static qualification reason #{index}",
        scope_label: "Fixture scope #{index}",
        owner: "Qualification owner",
        age: "#{index} minutes",
        destination_href: "/__qualification/hypermedia?view=c2#hui-c2-attention",
        destination_label: "Open attention fixture",
        evidence_href: "/__qualification/hypermedia?view=c2#hui-c2-trust",
        evidence_label: "View fixture evidence"
      }
    end)
  end

  defp health_items do
    Enum.map(1..13, fn index ->
      %{
        label: "Health metric #{index}",
        value: "#{100 - index}%",
        detail: "Bounded static observation #{index}",
        status: if(rem(index, 3) == 0, do: :attention, else: :healthy)
      }
    end)
  end

  defp fleet_rows(selection) do
    rows = [
      %{
        project: @hostile,
        project_href: "/__qualification/hypermedia?view=c2#hui-c2-fleet",
        work: "Primitive integration",
        agent: "Fixture Alpha",
        stage: "Review",
        health: "Ready",
        health_state: :ready,
        freshness: "Current"
      },
      %{
        project: String.duplicate("Long project label ", 18),
        work: "Responsive collection",
        agent: "Fixture Beta",
        stage: "Qualification",
        health: "Stale",
        health_state: :stale,
        freshness: "12 minutes old"
      },
      %{
        project: "Project with missing optional destination",
        work: nil,
        agent: nil,
        stage: nil,
        health: nil,
        health_state: :incomplete,
        freshness: nil
      }
    ]

    direction = if(selection.direction == :ascending, do: :asc, else: :desc)

    Enum.sort_by(
      rows,
      fn row -> row |> Map.get(selection.sort_column) |> to_string() |> String.downcase() end,
      direction
    )
  end

  defp normalize_selection(params) do
    state = closed_param(params, "state", @filter_states, "ready")
    sort = closed_param(params, "sort", @sort_columns, "project")
    direction = closed_param(params, "direction", @sort_directions, "ascending")

    %{
      query: bounded_param(params, "q", "hostile fixture", 80),
      state: state,
      state_atom: String.to_existing_atom(state),
      page: bounded_page(params),
      sort: sort,
      sort_column: String.to_existing_atom(sort),
      direction: String.to_existing_atom(direction),
      catalog_label: bounded_param(params, "catalog_label", @hostile, 180),
      qualified_label: bounded_param(params, "qualified_label", "Qualified facade field", 180),
      density: closed_param(params, "density", @densities, "comfortable"),
      include_archived: closed_boolean(params, "include_archived", true),
      mode: closed_param(params, "mode", @modes, "summary")
    }
  end

  defp bounded_param(params, key, fallback, limit) do
    case Map.get(params, key) do
      value when is_binary(value) ->
        value
        |> valid_string(fallback)
        |> String.replace(~r/[\x00-\x1F\x7F]/u, " ")
        |> String.trim()
        |> String.slice(0, limit)

      _other ->
        fallback
    end
  end

  defp valid_string(value, fallback), do: if(String.valid?(value), do: value, else: fallback)

  defp closed_param(params, key, allowed, fallback) do
    case Map.get(params, key) do
      value when is_binary(value) -> if(value in allowed, do: value, else: fallback)
      _other -> fallback
    end
  end

  defp closed_boolean(params, key, fallback) do
    case Map.fetch(params, key) do
      {:ok, value} when value in [true, "true", "1", "on"] -> true
      {:ok, value} when value in [false, "false", "0", "off"] -> false
      {:ok, _other} -> fallback
      :error -> fallback
    end
  end

  defp bounded_page(params) do
    case Map.get(params, "page") do
      value when is_binary(value) ->
        case Integer.parse(value) do
          {page, ""} when page in 1..@page_count -> page
          _other -> 2
        end

      page when is_integer(page) and page in 1..@page_count ->
        page

      _other ->
        2
    end
  end

  defp pages(selection) do
    Enum.map(1..@page_count, fn page ->
      if page == selection.page do
        %{key: Integer.to_string(page), label: Integer.to_string(page), current: true}
      else
        %{
          key: Integer.to_string(page),
          label: Integer.to_string(page),
          href: qualification_href(selection, %{page: page}),
          current: false
        }
      end
    end)
  end

  defp pagination_link(_selection, page, _label) when page < 1 or page > @page_count, do: nil

  defp pagination_link(selection, page, label),
    do: %{label: label, href: qualification_href(selection, %{page: page})}

  defp page_href(_selection, page) when page < 1 or page > @page_count, do: nil
  defp page_href(selection, page), do: qualification_href(selection, %{page: page})

  defp sort_hrefs(selection) do
    Map.new(@sort_columns, fn column ->
      next_direction =
        if selection.sort == column and selection.direction == :ascending,
          do: :descending,
          else: :ascending

      {String.to_existing_atom(column),
       qualification_href(selection, %{sort: column, direction: next_direction})}
    end)
  end

  defp qualification_href(selection, overrides) do
    query =
      %{
        "view" => "c2",
        "q" => selection.query,
        "state" => selection.state,
        "page" => selection.page,
        "sort" => selection.sort,
        "direction" => selection.direction
      }
      |> Map.merge(Map.new(overrides, fn {key, value} -> {Atom.to_string(key), value} end))
      |> URI.encode_query()

    "/__qualification/hypermedia?#{query}"
  end

  defp attempt do
    %{
      label: "Read-only HUI-C2 qualification attempt",
      project: "Milestone C",
      task: "Phase 2 component system",
      agent: "Deterministic fixture",
      profile: "Native-first",
      runtime: "Server-rendered HEEx",
      revision: "fixture-c2-1",
      fence: "Read-only",
      freshness: "Current",
      lifecycle_steps: [
        %{label: "Primitive facade", state: :complete},
        %{label: "Application shell", state: :complete},
        %{label: "Projection components", state: :current},
        %{label: "Integration evidence", state: :upcoming}
      ],
      outcomes: [
        %{label: "Native composition rendered", state: :observed, as_of: "Fixture render"},
        %{label: "Clean-checkout evidence pending", state: :pending}
      ],
      budget: %{label: "Fixture display budget", value: 73, max: 100, unit: "percent"}
    }
  end
end
