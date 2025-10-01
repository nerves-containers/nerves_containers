defmodule NervesContainers.MixProject do
  use Mix.Project

  def project do
    [
      app: :nerves_containers,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {NervesContainers.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:vintage_net, ">= 0.0.0"},
      {:muontrap, "~> 1.6"}
    ]
  end
end
