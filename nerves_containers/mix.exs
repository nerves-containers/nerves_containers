defmodule NervesContainers.MixProject do
  use Mix.Project

  @app :nerves_containers
  @version "0.1.0"
  @all_targets [
    :rpi,
    # :rpi0,
    # :rpi2,
    :rpi3,
    :rpi3_64,
    # :rpi3a,
    :rpi4,
    # :bbb,
    # :osd32mp1,
    :x86_64,
    :x86_64_efi,
    :bananapi_m1
  ]

  @wifi_targets [
    :rpi3,
    :rpi3_64,
    :rpi4,
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
      {:nerves_pack, "~> 0.5.0", targets: @all_targets},

      # wifi
      {:vintage_net_wizard, "~> 0.4", targets: @wifi_targets},

      # Dependencies for specific targets
      {:nerves_containers_rpi,
       git: gitlab_prefix() <> "nerves-containers/nerves_containers_rpi.git",
       branch: "development",
       runtime: false,
       targets: :rpi},
      {:nerves_containers_rpi3,
       git: gitlab_prefix() <> "nerves-containers/nerves_containers_rpi3.git",
       branch: "development",
       runtime: false,
       targets: :rpi3},
      {:nerves_containers_rpi3_64,
       git: gitlab_prefix() <> "nerves-containers/nerves_containers_rpi3.git",
       branch: "development-64",
       runtime: false,
       targets: :rpi3_64},
      {:nerves_containers_rpi4,
       git: gitlab_prefix() <> "nerves-containers/nerves_containers_rpi4.git",
       branch: "development",
       runtime: false,
       targets: :rpi4},
      {:nerves_containers_x86_64,
       git: gitlab_prefix() <> "nerves-containers/nerves_containers_x86_64.git",
       branch: "development",
       runtime: false,
       targets: :x86_64},
      {:nerves_containers_x86_64_uefi,
       git: gitlab_prefix() <> "nerves-containers/nerves_containers_x86_64_uefi.git",
       branch: "development",
       runtime: false,
       targets: :x86_64_efi},
      {:nerves_containers_bananapi_m1,
       git: gitlab_prefix() <> "nerves-containers/nerves_containers_bananapi_m1.git",
       branch: "development",
       runtime: false,
       targets: :bananapi_m1}
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
