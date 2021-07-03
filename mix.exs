defmodule NervesPodman.MixProject do
  use Mix.Project

  @app :nerves_podman
  @version "0.1.0"
  @all_targets [
    :rpi,
    #:rpi0,
    #:rpi2,
    #:rpi3,
    #:rpi3a,
    :rpi4,
    #:bbb,
    #:osd32mp1,
    :x86_64
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
      mod: {NervesPodman.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dependencies for all targets
      {:nerves, "~> 1.7.0", runtime: false},
      {:shoehorn, "~> 0.7.0"},
      {:ring_logger, "~> 0.8.1"},
      {:toolshed, "~> 0.2.13"},

      # Dependencies for all targets except :host
      {:nerves_runtime, "~> 0.11.3", targets: @all_targets},
      {:nerves_pack, "~> 0.4.0", targets: @all_targets},

      # Dependencies for specific targets
      {:nerves_system_rpi,
       git: "git@github.com:nerves-containers/nerves_containers_rpi.git",
       tag: "development",
       runtime: false,
       targets: :rpi,
       nerves: [compile: true]},
      {:nerves_containers_rpi4,
       git: "git@github.com:nerves-containers/nerves_containers_rpi4.git",
       tag: "development",
       runtime: false,
       targets: :rpi4,
       nerves: [compile: true]},
      {:nerves_system_x86_64,
       git: "git@github.com:nerves-containers/nerves_containers_x86_64.git",
       tag: "development",
       runtime: false,
       targets: :x86_64,
       nerves: [compile: true]}
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
