defmodule Garuda.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :garuda,
      version: "0.1.0",
      elixir: "~> 1.10",
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      name: "Garuda",
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

  defp docs do
    [
      logo: "logo.png",
      groups_for_modules: groups_for_modules()
    ]
  end

  defp groups_for_modules do
    [
      Frameworks: [
        Garuda.GameSocket,
        Garuda.GameChannel,
        Garuda.GameRoom
      ],
      RoomManager: [
        Garuda.RoomManager.RoomSheduler,
        Garuda.RoomManager,
        Garuda.RoomManager.RoomDb,
        Garuda.RoomManager.Records
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.5.3"},
      {:phoenix_html, "~> 2.14.1 or ~> 2.15"},
      {:jason, "~> 1.0"},
      {:phoenix_live_view, "~> 0.12.0 or ~> 0.14.4"},
      {:uuid, "~> 1.1.8"},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false}
    ]
  end
end
