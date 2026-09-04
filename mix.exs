defmodule JidoCode.MixProject do
  use Mix.Project

  def project do
    [
      app: :jido_code,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/project.plt"},
        plt_core_path: "priv/plts/core.plt",
        plt_add_apps: [:mix],
        ignore_warnings: ".dialyzer_ignore.exs"
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {JidoCode.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:live_vue, "~> 1.0"},
      {:phoenix_vite, "~> 0.4"},
      {:phoenix, "== 1.8.11"},
      {:phoenix_html, "== 4.3.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      # Phoenix.Component is currently distributed with Phoenix LiveView.
      # Keep this exact resolution as component infrastructure; HUI-B2 does not
      # authorize new LiveView product routes, sockets, processes, or state.
      {:phoenix_live_view, "== 1.2.9"},
      {:shadcn_ui,
       git: "https://github.com/pcharbon70/shadcn_ui.git",
       ref: "fe40eae63504adc4375aead4f0e741f158a4d86e"},
      {:dstar, "== 0.2.0"},
      # Dialyxir 1.4.7 predates OTP 28's opaque comparison warning formats.
      # Pin the upstream formatter support until it is included in a Hex release.
      {:dialyxir,
       git: "https://github.com/jeremyjh/dialyxir.git",
       ref: "3553678f4d69281ac6db61034bcf35bcb30cfd78",
       only: [:dev, :test],
       runtime: false},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      # Exact compatibility release required by the qualified LiveView 1.2 graph.
      {:salad_ui, "== 1.0.0"},
      # RDF 2.1 still declares Decimal 2.x, whose exponent parser is vulnerable
      # to unbounded allocation. Decimal 3 retains the API RDF uses.
      {:decimal, "~> 3.1", override: true},
      {:rdf, "~> 2.1"},
      {:jido, "== 2.3.2"},
      # JidoHarness 2.0 is not released on Hex. The reviewed source is pinned
      # exactly; its archive digest is enforced by the adoption contract.
      {:jido_harness,
       git: "https://github.com/agentjido/jido_harness.git",
       ref: "e41fc1651282469f2db4219a48d9f7feef1b0dbc"},
      # JidoHarness 2.0 constrains erlexec to the now-retired 2.3 line.
      # Keep its process boundary on the supported 2.4 release.
      {:erlexec, "~> 2.4", override: true},
      {:req_llm, "== 1.20.0"},
      {:triple_store,
       git: "https://github.com/pcharbon70/triple_store.git",
       ref: "6dc1b6d985f4805f9856858e0c0047b9f2d5ad7f"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.6.1"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["phoenix_vite.npm assets install"],
      "assets.build": [
        "compile",
        "phoenix_vite.npm vite build --manifest --emptyOutDir true",
        "phoenix_vite.npm vite build --ssrManifest --emptyOutDir false --ssr js/server.js --outDir ../priv/static"
      ],
      "assets.deploy": [
        "assets.build",
        "phx.digest"
      ],
      precommit: [
        "compile --warnings-as-errors",
        "architecture.check",
        "deps.unlock --unused",
        "format",
        "test"
      ]
    ]
  end
end
