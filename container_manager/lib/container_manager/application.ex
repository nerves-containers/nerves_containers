defmodule ContainerManager.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ContainerManager.Supervisor]

    if target() != :host do
      if Application.get_env(:container_manager, :use_cgroupfs_mount, false) do
        MuonTrap.cmd("cgroupfs-mount", [])
      end
      # create directory for the balena-engine, symlinked to /etc
      File.mkdir_p("/data/etc/balena-engine")
      # write daemon config
      daemon_config = Application.get_env(:container_manager, :daemon_config, %{})
      File.write!("/data/etc/balena-engine/daemon.json", Jason.encode!(daemon_config))
    end

    children =
      [
        # Children for all targets
        # Starts a worker by calling: ContainerManager.Worker.start_link(arg)
        # {ContainerManager.Worker, arg},
      ] ++ children(target())

    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: ContainerManager.Worker.start_link(arg)
      # {ContainerManager.Worker, arg},
    ]
  end

  def children(_target) do
    [
      # Children for all targets except host
      # Starts a worker by calling: ContainerManager.Worker.start_link(arg)
      # {ContainerManager.Worker, arg},
      {MuonTrap.Daemon,
       [
         "balena-engine-daemon",
         [
           "--data-root",
           "/data/balena",
           "--experimental"
         ],
         []
       ]}
    ]
  end

  def target() do
    Application.get_env(:container_manager, :target, :host)
  end
end
