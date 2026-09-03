This is a web application written using the Phoenix web framework.

## Project guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps

### Planning phase closure pattern

Implementation plans live in `docs/planning/<plan-name>/phase-NN-*.md` checklists, and each phase records its evidence in `docs/architecture/phase-NN-receipt.md`. Implement each numbered section as a distinct commit and use one implementation pull request per phase. A phase closes only after that pull request passes clean-checkout CI and merges:

1. In the phase receipt, pin the merged candidate: record the full merge-commit SHA in `Candidate Provenance`, change the Status and `Gate GN` sections from "merge-pending" to accepted-at-merged-candidate, and note the merge date. Keep every gate reopening condition intact; never weaken or delete them.
2. In the plan file, tick the phase-level checkbox, the final `Phase N Integration Tests` section checkbox, the phase-receipt task checkbox, and the `Pin the merged candidate commit` subtask.
3. The next phase is authorized only from that pinned baseline.

When the merged-candidate SHA cannot exist before the implementation merge, publish the receipt transition in a narrowly scoped closure pull request. Sync local `main` from `origin/main` before deleting either merged branch. A gate reopens if any of its listed invariants fails, regardless of checkbox state.

### Phoenix v1.8 product guidelines

- New product pages, fragments, actions, exports, and streams use explicit Phoenix routes, controllers, HTML modules, and HEEx templates. Do not add product LiveView routes, modules, processes, events, streams, assigns, hooks, or LiveVue islands.
- Render full pages through the application layout and pass the trusted current scope explicitly from the controller. Fragments use stable, documented root DOM IDs and never acquire independent authority.
- Construct named human identity, exact tenant/project/graph scope, delegation, assurance, policy revision, and graph revisions in trusted Plugs or controller helpers. Never derive grants or authoritative revisions from params, headers, Datastar signals, DOM state, or browser storage.
- Enforce route admission before rendering, then repeat exact resource/action authorization before every query, field shape, protected patch, semantic command, approval, export, and download. Conceal existence where policy requires it and redact fields before rendering.
- State-changing routes use non-GET verbs, CSRF validation, same-origin/Origin enforcement, closed parameter schemas, idempotency or optimistic revisions where required, and immutable semantic receipts. High-risk actions require current step-up and separation-of-duty policy.
- Datastar is progressive enhancement only: signals are untrusted ephemeral intent, fragments are server-rendered, SSE uses an application-owned coordinator with bounded lifetime and reauthorization before every protected patch, and ordinary links/forms provide native fallback where feasible.
- Use one local `app.js` and one local `app.css` bundle. Keep CSP compatible with the accepted nonce mode, use static reviewed Datastar expressions, and prohibit inline scripts, remote/CDN product assets, and executable content from source, wiki, graph, log, or agent data.
- The `JidoCodeWeb.Layouts` and component helpers are available through `use JidoCodeWeb, :html`; do not create a second presentation framework or bypass the `JidoCodeWeb.Components.UI` facade.
- `<.flash_group>` belongs only in `layouts.ex`.
- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will will save steps and prevent errors
- If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your
custom classes must fully style the input

### JS and CSS guidelines

- **Use Tailwind CSS classes and custom CSS rules** to create polished, responsive, and visually stunning interfaces.
- Tailwindcss v4 **no longer needs a tailwind.config.js** and uses a new import syntax in `app.css`:

      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/my_app_web";

- **Always use and maintain this import syntax** in the app.css file for projects generated with `phx.new`
- **Never** use `@apply` when writing raw css
- **Always** manually write your own tailwind-based components instead of using daisyUI for a unique, world-class design
- Out of the box **only the app.js and app.css bundles are supported**
  - You cannot reference an external vendor'd script `src` or link `href` in the layouts
  - You must import the vendor deps into app.js and app.css to use them
  - **Never write inline <script>custom js</script> tags within templates**

### UI/UX & design guidelines

- **Produce world-class UI designs** with a focus on usability, aesthetics, and modern design principles
- Implement **subtle micro-interactions** (e.g., button hover effects, and smooth transitions)
- Ensure **clean typography, spacing, and layout balance** for a refined, premium look
- Focus on **delightful details** like hover effects, loading states, and smooth page transitions


<!-- usage-rules-start -->

<!-- phoenix:elixir-start -->
## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: the inner rebinding does not escape the block
      if enabled? do
        result = compute_result()
      end

      # VALID: we rebind the result of the `if` to a new variable
      result =
        if enabled? do
          compute_result()
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason
<!-- phoenix:elixir-end -->

<!-- phoenix:phoenix-start -->
## Phoenix guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        get "/users", UserController, :index
      end

  the route points to the `AppWeb.Admin.UserController` module

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it
<!-- phoenix:phoenix-end -->

<!-- phoenix:html-start -->
## Phoenix HTML guidelines

- Phoenix templates **always** use `~H` or .html.heex files (known as HEEx), **never** use `~E`
- **Always** use the imported `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` function to build forms. **Never** use `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for` as they are outdated
- When building forms **always** use `Phoenix.Component.to_form/2` in the controller or HTML boundary, assign the resulting form to the template, render `<.form for={@form} id="msg-form">`, and access fields through `@form[:field]`
- **Always** add unique DOM IDs to key elements (like forms, buttons, fragments, status regions, and stream roots) so controller and browser tests can target stable contracts
- For app-wide template imports, import or alias through `jido_code_web.ex`'s `html_helpers` block so they are available to controllers' HTML modules, templates, and modules using `use JidoCodeWeb, :html`

- Elixir supports `if/else` but **does NOT support `if/else if` or `if/elsif`. **Never use `else if` or `elseif` in Elixir**, **always** use `cond` or `case` for multiple conditionals.

  **Never do this (invalid)**:

      <%= if condition do %>
        ...
      <% else if other_condition %>
        ...
      <% end %>

  Instead **always** do this:

      <%= cond do %>
        <% condition -> %>
          ...
        <% condition2 -> %>
          ...
        <% true -> %>
          ...
      <% end %>

- HEEx require special tag annotation if you want to insert literal curly's like `{` or `}`. If you want to show a textual code snippet on the page in a `<pre>` or `<code>` block you *must* annotate the parent tag with `phx-no-curly-interpolation`:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>

  Within `phx-no-curly-interpolation` annotated tags, you can use `{` and `}` without escaping them, and dynamic Elixir expressions can still be used with `<%= ... %>` syntax

- HEEx class attrs support lists, but you must **always** use list `[...]` syntax. You can use the class list syntax to conditionally add classes, **always do this for multiple class values**:

      <a class={[
        "px-2 text-white",
        @some_flag && "py-5",
        if(@other_condition, do: "border-red-500", else: "border-blue-100"),
        ...
      ]}>Text</a>

  and **always** wrap `if`'s inside `{...}` expressions with parens, like done above (`if(@other_condition, do: "...", else: "...")`)

  and **never** do this, since it's invalid (note the missing `[` and `]`):

      <a class={
        "px-2 text-white",
        @some_flag && "py-5"
      }> ...
      => Raises compile syntax error on invalid HEEx attr syntax

- **Never** use `<% Enum.each %>` or non-for comprehensions for generating template content, instead **always** use `<%= for item <- @collection do %>`
- HEEx HTML comments use `<%!-- comment --%>`. **Always** use the HEEx HTML comment syntax for template comments (`<%!-- comment --%>`)
- HEEx allows interpolation via `{...}` and `<%= ... %>`, but the `<%= %>` **only** works within tag bodies. **Always** use the `{...}` syntax for interpolation within tag attributes, and for interpolation of values within tag bodies. **Always** interpolate block constructs (if, cond, case, for) within tag bodies using `<%= ... %>`.

  **Always** do this:

      <div id={@id}>
        {@my_assign}
        <%= if @some_block_condition do %>
          {@another_assign}
        <% end %>
      </div>

  and **Never** do this – the program will terminate with a syntax error:

      <%!-- THIS IS INVALID NEVER EVER DO THIS --%>
      <div id="<%= @invalid_interpolation %>">
        {if @invalid_block_construct do}
        {end}
      </div>
<!-- phoenix:html-end -->

<!-- phoenix:hypermedia-start -->
## Controller, HEEx, and Datastar guidelines

- New product routes must be explicit `get`, `post`, `put`, `patch`, or `delete` controller routes. Product `live`, `live_session`, LiveView, LiveComponent, LiveVue, and SaladUI additions are prohibited; the tracked current consumers are compatibility-only until their accepted removal gates close.
- Page and fragment controllers return bounded projections from reviewed query interfaces. They never issue raw SPARQL, access TripleStore directly, choose graph IRIs from caller data, or invoke runtime effects.
- Semantic effects run only through the accepted command gateway. Reconstruct actor, authority, resource, action, revisions, assurance, delegation, and incident posture server-side immediately before the effect; return the durable receipt outcome rather than optimistic browser state.
- Every protected page, fragment, stream, command, approval, export, and download fails closed for missing or stale authority. Use policy-defined concealment, safe redaction, step-up, and terminal revocation behavior; never union roles or sessions in the browser.
- Render ordinary anchor and form behavior first. Enhanced requests use closed signal schemas, stable fragment roots, bounded patch size/root count, explicit safe outcomes, and static expressions. Browser signals and revisions are hints only.
- Protected SSE starts only after authentication and authorization complete, sends a current authorized snapshot, reauthorizes and requeries before every protected patch, has a maximum lifetime and reauthorization interval, and terminates with replacement/close/reconnect suppression on revocation.
- Keep scripts in `assets/js/app.js` and styles in `assets/css/app.css`. Do not place inline script tags or event-handler JavaScript in HEEx, load remote product assets, evaluate server/user content as Datastar expressions, or persist authority in browser storage.
- Build forms with `to_form/2`, `<.form for={@form}>`, and `<.input>`. Give every form a unique DOM ID, use ordinary `action` and `method` attributes for native fallback, and include CSRF protection. Templates consume form assigns, never changesets directly.
- Controller tests use `Phoenix.ConnTest`; parse rendered HTML with `LazyHTML` and assert stable element IDs and outcomes. Add real-browser tests for enhancement, focus, keyboard, accessibility, reconnect, and native fallback when the relevant milestone requires them. Do not use raw string assertions for HTML structure.
- Product surfaces must preserve keyboard operation, visible focus, semantic landmarks, labels, status announcements, reduced-motion behavior, accessible alternatives for graphs/visualizations, and bounded responsive layouts.
- Wiki views preserve repository/tenant/session isolation, immutable edition identity, default-off enrollment, redaction, review/activation separation, and exact token reservation/usage/cost attribution. Parallel browser sessions must converge through server-owned revisions and return explicit conflict receipts rather than last-writer-wins state.
- Any temporary architecture exception must be a reviewed record with an owner, reason, exact path and symbol, expiry, evidence, and reopening condition. Expired, widened, or unmatched exceptions fail `mix architecture.check`.

### Form handling

Controllers prepare parameter-backed or changeset-backed forms with `to_form/2` and pass them to the HTML template. Name nested parameter forms explicitly:

    form = to_form(user_params, as: :user)
    render(conn, :edit, form: form)

In the template, always use the assigned form and stable IDs:

    <.form for={@form} id="user-form" action={~p"/users"} method="post">
      <.input field={@form[:name]} type="text" />
    </.form>

Never pass a changeset directly to `<.form>`, never access a changeset as `@changeset[:field]`, and never use `<.form let={f}>`.
<!-- phoenix:hypermedia-end -->

<!-- usage-rules-end -->
