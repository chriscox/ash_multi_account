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
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Core Ash
      {:ash, "~> 3.0"},
      {:ash_authentication, "~> 4.0"},
      {:spark, "~> 2.0"},

      # Phoenix
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 1.0"},

      # Dev/test
      {:sourceror, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
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
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
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
