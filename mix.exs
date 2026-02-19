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
      # Core Ash
      {:ash, "~> 3.0"},
      {:spark, "~> 2.0"},

      # Optional — needed for Phase 3 (Phoenix integration)
      {:ash_authentication, "~> 4.0", optional: true},
      {:phoenix, "~> 1.7", optional: true},
      {:phoenix_live_view, "~> 1.0", optional: true},

      # Dev/test
      {:sourceror, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:igniter, "~> 0.6", only: [:dev], runtime: false},
      {:usage_rules, "~> 1.1", only: [:dev], runtime: false}
    ]
  end

  defp aliases do
    [
      ci: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "credo --strict",
        "test"
      ]
    ]
  end

  defp package do
    [
      name: "ash_multi_account",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md usage-rules.md)
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
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
