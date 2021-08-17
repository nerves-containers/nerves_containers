defmodule NervesContainers.MixProject do
  use Mix.Project

  @app :nerves_containers
  @version "0.1.0"
  @all_targets [
    :rpi,
    # :rpi0,
    # :rpi2,
    # :rpi3,
    # :rpi3a,
    :rpi4,
    # :bbb,
    # :osd32mp1,
    :x86_64,
    :x86_64_efi
  ]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.9",
      archives: [nerves_bootstrap: "~> 1.10"],
      start_permanent: Mix.env() == :prod,
      build_embedded: true,
      deps: deps(),
      releases: [{@app, release()}],
      preferred_cli_target: [run: :host, test: :host]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {NervesContainers.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp gitlab_prefix() do
    if System.get_env("CI") != nil do
      # use HTTPS cloning in gitlab CI
      "https://gitlab.com/"
    else
      # use SSH in any other case
      "git@gitlab.com:"
    end
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dependencies for all targets
      {:nerves, "~> 1.7.0", runtime: false},
      {:shoehorn, "~> 0.7.0"},
      {:ring_logger, "~> 0.8.1"},
      {:toolshed, "~> 0.2.13"},
      {:container_manager, path: "../container_manager"},

      # Dependencies for all targets except :host
      {:nerves_runtime, "~> 0.11.3", targets: @all_targets},
      {:nerves_pack, "~> 0.4.0", targets: @all_targets},

      # Dependencies for specific targets
      {:nerves_containers_x86_64_uefi,
       git: gitlab_prefix() <> "nerves-containers/nerves_containers_x86_64_uefi.git",
       tag: "development",
       runtime: false,
       targets: :x86_64_efi}
    ]
  end

  def release do
    [
      overwrite: true,
      # Erlang distribution is not started automatically.
      # See https://hexdocs.pm/nerves_pack/readme.html#erlang-distribution
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod or [keep: ["Docs"]]
    ]
  end
end
