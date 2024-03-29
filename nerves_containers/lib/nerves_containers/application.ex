defmodule NervesContainers.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NervesContainers.Supervisor]

    children =
      [
        # Children for all targets
        # Starts a worker by calling: NervesContainers.Worker.start_link(arg)
        # {NervesContainers.Worker, arg},
        {NervesSSH,
         NervesSSH.Options.with_defaults(
           Application.get_all_env(:nerves_ssh)
           |> Keyword.merge(
             name: :shell,
             port: 2222,
             shell: :disabled,
             daemon_option_overrides: [{:ssh_cli, {NervesSSH.SystemShell, []}}]
           )
         )}
      ] ++ children(target())

    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: NervesContainers.Worker.start_link(arg)
      # {NervesContainers.Worker, arg},
    ]
  end

  def children(_target) do
    [
      # Children for all targets except host
      # Starts a worker by calling: NervesContainers.Worker.start_link(arg)
      # {NervesContainers.Worker, arg},
      NervesContainers.NetworkManager
    ]
  end

  def target() do
    Application.get_env(:nerves_containers, :target, :host)
  end
end
