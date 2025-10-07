defmodule NervesContainers.MaybeWaitForInternet do
  @moduledoc """
  A module that delays the application start until an internet connection is available.

  This is relevant because docker takes what’s in
  /etc/resolv.conf (nothing at boot) and holds on to it, meaning containers
  will never have working networking if it starts too early.

  For simplicity we simply wait until VintageNet says we have working internet.
  This should be adapted if internet is not needed for the application to work,
  e.g., because a docker registry on the local LAN is used.
  """

  require Logger

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :transient,
      shutdown: 500
    }
  end

  @doc false
  def start_link do
    if Application.get_env(:nerves_containers, :wait_for_internet, true) do
      if VintageNet.get(["connection"]) == :internet do
        :ignore
      else
        Logger.info("""
        Delaying start of nerves_containers because no internet connection is available!

        If you do not need an internet connection for docker, you can set

        config :nerves_containers, wait_for_internet: false
        """)

        wait_for_internet(1)
      end
    else
      :ignore
    end
  end

  defp wait_for_internet(n) do
    Process.sleep(5000)

    if VintageNet.get(["connection"]) == :internet do
      :ignore
    else
      Logger.info("Still waiting for internet connection. Try #{n + 1}...")

      wait_for_internet(n + 1)
    end
  end
end
