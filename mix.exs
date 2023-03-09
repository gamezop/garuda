defmodule Garuda.MixProject do
  @moduledoc false
  use Mix.Project

  @version "0.3.0"
  def project do
    [
      app: :garuda,
      version: @version,
      elixir: "~> 1.10",
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      name: "Garuda",
      package: package(),
      aliases: aliases(),
      description: """
        A multiplayer game server framework for phoenix.
      """
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp aliases do
    [docs: ["docs", &copy_images/1]]
  end

  defp copy_images(_) do
    File.cp_r("source", "destination", fn source, destination ->
      IO.gets("Overwriting #{destination} by #{source}. Type y to confirm. ") == "y\n"
    end)
  end

  defp docs do
    [
      logo: "logo.png",
      groups_for_modules: groups_for_modules(),
      extra_section: "GUIDES",
      extras: extras(),
      main: "overview"
    ]
  end

  defp extras do
    [
      "guides/overview.md",
      "guides/server.md",
      "guides/client.md",
      "guides/monitoring.md"
    ]
  end

  defp groups_for_modules do
    [
      Frameworks: [
        Garuda.GameSocket,
        Garuda.GameChannel,
        Garuda.GameRoom
      ]
    ]
  end

  defp package() do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/madclaws/garuda"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.6.8"},
      {:phoenix_view, "~> 2.0"},
      {:phoenix_html, "~> 3.3.1"},
      {:jason, "~> 1.0"},
      {:phoenix_live_view, "~> 0.18.3"},
      {:phoenix_live_dashboard, "~> 0.7.2"},
      {:uuid, "~> 1.1.8"},
      {:msgpax, "~> 2.0"},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false}
    ]
  end
end
