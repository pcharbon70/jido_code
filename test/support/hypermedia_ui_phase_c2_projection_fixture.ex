defmodule JidoCodeWeb.HypermediaUIPhaseC2ProjectionFixture do
  @moduledoc false

  use Phoenix.Component

  alias JidoCodeWeb.Components.Projection

  @hostile ~s|<script data-c2-projection-hostile>window.unsafe()</script><b>& "quoted"</b>|

  attr :scenario, :atom, default: :ready
  attr :hostile_content, :string, default: @hostile

  def render(assigns) do
    data = scenario(assigns.scenario, assigns.hostile_content)
    assigns = assign(assigns, :data, data)

    ~H"""
    <main id="hui-c2-projection-fixture" aria-labelledby="hui-c2-projection-fixture-title">
      <h1 id="hui-c2-projection-fixture-title">Projection component fixture</h1>

      <Projection.trust_header
        id="hui-c2-trust"
        state={@data.state}
        title={@data.title}
        revision={@data.revision}
        freshness={@data.freshness}
        source={@data.source}
        as_of={@data.as_of}
        completeness={@data.completeness}
      />

      <Projection.attention_list
        id="hui-c2-attention"
        state={@data.state}
        title="Needs attention"
        items={@data.attention}
        retry_href="?retry=attention"
      />

      <Projection.health_summary
        id="hui-c2-health"
        state={@data.state}
        items={@data.health}
        retry_href="?retry=health"
      />

      <Projection.fleet_project_table
        id="hui-c2-fleet"
        state={@data.state}
        rows={@data.fleet}
        sort_column={:project}
        sort_direction={:ascending}
        sort_hrefs={
          %{
            project: "?sort=project&direction=descending",
            stage: "?sort=stage&direction=ascending"
          }
        }
        page={1}
        page_count={3}
        next_href="?page=2"
        retry_href="?retry=fleet"
      />

      <Projection.attempt_summary
        id="hui-c2-attempt"
        state={@data.state}
        attempt={@data.attempt}
        retry_href="?retry=attempt"
      />

      <div id="hui-c2-projection-links">
        <Projection.evidence_link
          id="hui-c2-evidence-link"
          state={@data.state}
          href="/reviews/evidence-ref"
          label="View verification evidence"
        />
        <Projection.evidence_link
          id="hui-c2-receipt-link"
          state={@data.state}
          kind={:receipt}
          href="/reviews/receipt-ref"
          label="View semantic receipt"
        />
        <Projection.readiness_badge id="hui-c2-readiness" state={@data.state} />
      </div>
    </main>
    """
  end

  attr :state, :any, required: true
  attr :secret, :string, default: "protected-row-must-not-render"

  def protected(assigns) do
    secret = assigns.secret

    assigns =
      assigns
      |> assign(:attention, [attention_item(secret, 1)])
      |> assign(:health, [health_item(secret, 1)])
      |> assign(:fleet, [fleet_row(secret, 1)])
      |> assign(:attempt, attempt(secret, 3))
      |> assign(:steps, lifecycle_steps(secret, 3))
      |> assign(:outcomes, outcomes(secret, 3))

    ~H"""
    <div id="hui-c2-protected-fixture">
      <Projection.projection_status
        id="hui-c2-protected-status"
        state={@state}
        title={@secret}
        message={@secret}
        retry_href="?retry=projection"
        retry_label={@secret}
      />
      <Projection.trust_header
        id="hui-c2-protected-trust"
        state={@state}
        title={@secret}
        revision={@secret}
        freshness={@secret}
        source={@secret}
        as_of={@secret}
        completeness={@secret}
      />
      <Projection.attention_list
        id="hui-c2-protected-attention"
        state={@state}
        title={@secret}
        items={@attention}
        empty_message={@secret}
        retry_href="?retry=attention"
      />
      <Projection.health_summary
        id="hui-c2-protected-health"
        state={@state}
        title={@secret}
        items={@health}
        retry_href="?retry=health"
      />
      <Projection.fleet_project_table
        id="hui-c2-protected-fleet"
        state={@state}
        title={@secret}
        caption={@secret}
        rows={@fleet}
        retry_href="?retry=fleet"
      />
      <Projection.attempt_summary
        id="hui-c2-protected-attempt"
        state={@state}
        attempt={@attempt}
        retry_href="?retry=attempt"
      />
      <Projection.lifecycle_rail
        id="hui-c2-protected-lifecycle"
        state={@state}
        title={@secret}
        steps={@steps}
      />
      <Projection.outcome_rail
        id="hui-c2-protected-outcomes"
        state={@state}
        title={@secret}
        items={@outcomes}
      />
      <Projection.budget_meter
        id="hui-c2-protected-budget"
        state={@state}
        label={@secret}
        value={99}
        max={100}
        unit={@secret}
      />
      <Projection.evidence_link
        id="hui-c2-protected-evidence"
        state={@state}
        kind={:receipt}
        href="/reviews/protected"
        label={@secret}
      />
      <Projection.readiness_badge
        id="hui-c2-protected-readiness"
        state={@state}
        label={@secret}
      />
    </div>
    """
  end

  defp scenario(:high_count, content) do
    %{
      state: :truncated,
      title: "Bounded high-count fixture",
      revision: "revision-high-count",
      freshness: "fresh",
      source: "bounded fixture",
      as_of: "2026-09-05T12:00:00Z",
      completeness: "Input exceeds component display ceilings",
      attention: Enum.map(1..80, &attention_item("#{content}-#{&1}", &1)),
      health: Enum.map(1..40, &health_item("#{content}-#{&1}", &1)),
      fleet: Enum.map(1..90, &fleet_row("#{content}-#{&1}", &1)),
      attempt: attempt(content, 30)
    }
  end

  defp scenario(:hostile, content) do
    normal = scenario(:ready, content)

    %{
      normal
      | title: content <> String.duplicate(" long", 80),
        revision: content,
        freshness: content,
        source: content,
        completeness: content,
        attention: [attention_item(content, 1)],
        health: [health_item(content, 1)],
        fleet: [fleet_row(content, 1)],
        attempt: attempt(content, 3)
    }
  end

  defp scenario(:missing, _content) do
    %{
      state: :ready,
      title: nil,
      revision: nil,
      freshness: nil,
      source: nil,
      as_of: nil,
      completeness: nil,
      attention: [%{}],
      health: [%{}],
      fleet: [%{}],
      attempt: %{}
    }
  end

  defp scenario(:stale, content), do: %{scenario(:ready, content) | state: :stale}
  defp scenario(:error, content), do: %{scenario(:ready, content) | state: :unavailable}
  defp scenario(:partial, content), do: %{scenario(:ready, content) | state: :partial}
  defp scenario(:concealed, content), do: %{scenario(:ready, content) | state: :concealed}

  defp scenario(_scenario, content) do
    %{
      state: :ready,
      title: "Factory projection trust",
      revision: "projection-r17",
      freshness: "Fresh within 30 seconds",
      source: "Reviewed factory projection",
      as_of: "2026-09-05T12:00:00Z",
      completeness: "Complete within the authorized scope",
      attention: [attention_item(content, 1), attention_item("Budget threshold", 2)],
      health: [health_item("Active attempts", 1), health_item("Waiting attempts", 2)],
      fleet: [fleet_row("Repository alpha", 1), fleet_row("Repository beta", 2)],
      attempt: attempt("Attempt alpha", 4)
    }
  end

  defp attention_item(content, index) do
    %{
      severity: if(rem(index, 2) == 0, do: :medium, else: :high),
      title: content,
      reason: "#{content} requires a current human review.",
      scope_label: "Project #{index}",
      owner: "Owner #{index}",
      age: "#{index} minutes",
      destination_href: "/projects/project-#{index}",
      destination_label: "Open project #{index}",
      evidence_href: "/reviews/evidence-#{index}",
      evidence_label: "View evidence #{index}"
    }
  end

  defp health_item(content, index) do
    %{
      label: content,
      value: index * 3,
      status: if(rem(index, 3) == 0, do: :attention, else: :healthy),
      detail: "Observed from an authorized summary #{index}."
    }
  end

  defp fleet_row(content, index) do
    %{
      project: content,
      project_href: "/projects/project-#{index}",
      work: "Task #{index}",
      agent: "Agent #{index}",
      stage: if(rem(index, 2) == 0, do: "Verifying", else: "Executing"),
      health: if(rem(index, 3) == 0, do: "Needs attention", else: "Ready"),
      health_state: if(rem(index, 3) == 0, do: :stale, else: :ready),
      freshness: "#{index} seconds ago"
    }
  end

  defp attempt(content, rail_count) do
    %{
      label: content,
      project: "Repository alpha",
      task: "Implement bounded projection components",
      agent: "Agent alpha",
      profile: "reviewed-profile",
      runtime: "runtime-ref",
      revision: "attempt-r9",
      fence: "fence-4",
      freshness: "Fresh within 30 seconds",
      lifecycle_steps: lifecycle_steps(content, rail_count),
      outcomes: outcomes(content, rail_count),
      budget: %{label: "Attempt token budget", value: 82, max: 100, unit: "percent"}
    }
  end

  defp lifecycle_steps(content, count) do
    Enum.map(1..count, fn index ->
      %{
        label: "#{content} stage #{index}",
        state:
          cond do
            index < 3 -> :complete
            index == 3 -> :current
            true -> :upcoming
          end
      }
    end)
  end

  defp outcomes(content, count) do
    Enum.map(1..count, fn index ->
      %{
        label: "#{content} outcome #{index}",
        state: if(index == count, do: :pending, else: :observed),
        as_of: "Evidence sequence #{index}"
      }
    end)
  end
end
