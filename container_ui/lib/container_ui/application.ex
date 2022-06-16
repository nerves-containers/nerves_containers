defmodule ContainerUI.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      ContainerUIWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: ContainerUI.PubSub},
      # Start the Endpoint (http/https)
      ContainerUIWeb.Endpoint,
      ContainerUI.ExecMonitor,
      {NervesSSH,
       %NervesSSH.Options{
         authorized_keys: [File.read!(Path.join(System.user_home!(), ".ssh/id_rsa.pub"))],
         port: 2222,
         system_dir: File.cwd!(),
         cli: {ContainerUI.DockerExecSSH, []},
         shell: :erlang,
         subsystems: [
           {'docker', {ContainerUI.DockerExecSSH, []}}
         ],
         daemon_option_overrides: [user_dir: File.cwd!() |> to_charlist()]
       }}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ContainerUI.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ContainerUIWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
