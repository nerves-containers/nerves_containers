defmodule NervesContainers.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # ensure the data directory exists, it is symlinked to /etc
    # by the systems' root fs overlay
    File.mkdir_p("/data/etc/balena-engine")

    children = [
      NervesContainers.MaybeWaitForInternet,
      NervesContainers.BalenaEngine
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NervesContainers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
