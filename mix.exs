defmodule AshMultiAccount.MixProject do
  use Mix.Project

  @version "0.1.0"
  @description "Multi-account linking and switching for Ash apps"
  @source_url "https://github.com/chriscox/ash_multi_account"

  def project do
    [
      app: :ash_multi_account,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      aliases: aliases(),
      package: package(),
      docs: docs(),
      name: "AshMultiAccount",
      description: @description,
      source_url: @source_url,
      homepage_url: @source_url,
      dialyzer: [plt_add_apps: [:mix]],
      usage_rules: usage_rules()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Core
      {:ash, "~> 3.0"},
      {:spark, "~> 2.0"},
      {:ash_authentication, "~> 4.0"},
      {:phoenix, "~> 1.7"},

      # Optional — LiveView and AshAuthentication Phoenix integration
      {:ash_authentication_phoenix, "~> 2.0", optional: true},
      {:phoenix_live_view, "~> 1.0", optional: true},

      # Optional — installer support (compile-time only)
      {:sourceror, "~> 1.7", optional: true, runtime: false},
      {:igniter, "~> 0.6", optional: true, runtime: false},

      # Dev/test
      {:ex_doc, "~> 0.34", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:usage_rules, "~> 1.1", only: [:dev], runtime: false}
    ]
  end

  defp aliases do
    extensions = [
      "AshMultiAccount",
      "AshMultiAccount.LinkedAccount"
    ]

    [
      ci: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "credo --strict",
        "test"
      ],
      "spark.formatter": "spark.formatter --extensions #{Enum.join(extensions, ",")}",
      "spark.cheat_sheets": "spark.cheat_sheets --extensions #{Enum.join(extensions, ",")}",
      docs: [
        "spark.cheat_sheets",
        "docs",
        "spark.replace_doc_links"
      ]
    ]
  end

  defp package do
    [
      name: "ash_multi_account",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files:
        ~w(lib documentation .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp usage_rules do
    [
      file: "CLAUDE.md",
      skills: [
        location: ".claude/skills",
        build: [
          "ash-framework": [
            description:
              "Use this skill working with Ash Framework or any of its extensions. Always consult this when making any domain changes, features or fixes.",
            usage_rules: [:ash, ~r/^ash_/]
          ],
          "phoenix-framework": [
            description:
              "Use this skill working with Phoenix Framework. Consult this when working with the web layer, controllers, views, liveviews etc.",
            usage_rules: [:phoenix, ~r/^phoenix_/]
          ]
        ]
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extra_section: "GUIDES",
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_modules: groups_for_modules()
    ]
  end

  defp extras do
    [
      {"README.md", name: "Home"},
      "CHANGELOG.md",
      "documentation/tutorials/getting-started.md",
      "documentation/topics/how-it-works.md",
      "documentation/topics/phoenix-integration.md",
      "documentation/topics/testing.md",
      "documentation/topics/customizing-the-account-switcher.md"
    ] ++ dsl_extras()
  end

  defp dsl_extras do
    if Code.ensure_loaded?(Spark.Docs) and Code.ensure_loaded?(AshMultiAccount) do
      [
        {"documentation/dsls/DSL-AshMultiAccount.md",
         search_data: Spark.Docs.search_data_for(AshMultiAccount)},
        {"documentation/dsls/DSL-AshMultiAccount.LinkedAccount.md",
         search_data: Spark.Docs.search_data_for(AshMultiAccount.LinkedAccount)}
      ]
    else
      [
        "documentation/dsls/DSL-AshMultiAccount.md",
        "documentation/dsls/DSL-AshMultiAccount.LinkedAccount.md"
      ]
    end
  end

  defp groups_for_extras do
    [
      "About Ash Multi Account": ~r"(README|CHANGELOG)\.md$",
      Tutorials: ~r"documentation/tutorials",
      Topics: ~r"documentation/topics",
      Reference: ~r"documentation/dsls"
    ]
  end

  defp groups_for_modules do
    [
      Extensions: [
        AshMultiAccount,
        AshMultiAccount.LinkedAccount
      ],
      "DSL & Introspection": [
        AshMultiAccount.Info,
        AshMultiAccount.LinkedAccount.Info
      ],
      "Phoenix Integration": [
        AshMultiAccount.Phoenix.Plug,
        AshMultiAccount.Phoenix.Router,
        AshMultiAccount.Phoenix.Controller,
        AshMultiAccount.Phoenix.Session,
        AshMultiAccount.Phoenix.LiveHook,
        AshMultiAccount.Phoenix.Components
      ],
      "Changes & Preparations": [
        AshMultiAccount.Changes.ValidateNotSelfLinked,
        AshMultiAccount.Changes.ValidateMaxLinkedAccounts,
        AshMultiAccount.Preparations.FilterLinkedAccounts,
        AshMultiAccount.Preparations.LoadLinkedUsers,
        AshMultiAccount.Preparations.LoadLinkedAccounts
      ],
      Calculations: [
        AshMultiAccount.Calculations.IsActive,
        AshMultiAccount.Calculations.LinkedAccountSessions
      ],
      Internals: ~r/.*/
    ]
  end
end
