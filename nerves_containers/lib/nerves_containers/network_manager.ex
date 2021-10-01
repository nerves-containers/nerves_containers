defmodule NervesContainers.NetworkManager do
  use GenServer
  require Logger

  @impl true
  def init(_) do
    VintageNet.subscribe(["connection"])

    {:ok, %{}, {:continue, :check_connection}}
  end

  @impl true
  def handle_continue(:check_connection, state) do
    if VintageNet.get(["connection"]) in [:internet, :lan] do
      {:noreply, state}
    end

    # when disconnected, set a timeout
    {:noreply, state, :timer.seconds(30)}
  end

  @impl true
  def handle_continue(:try_wizard, state) do
    interfaces =
      VintageNet.get_by_prefix(["interface"])
      |> Enum.filter(fn
        {["interface", _iface, "present"], true} -> true
        _other -> false
      end)
      |> Enum.map(fn {["interface", iface, "present"], true} -> iface end)
      |> Enum.filter(fn iface ->
        VintageNet.get(["interface", iface, "type"]) == VintageNetWiFi
      end)

    if length(interfaces) > 0 do
      Logger.info("Disconnected. Starting WiFi configuration wizard!")
      VintageNetWizard.run_if_unconfigured(ifname: Enum.at(interfaces, 0))
      {:noreply, state}
    else
      Logger.info("No WiFi interface available...")
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({VintageNet, ["connection"], _old_value, :disconnected, _meta}, state) do
    Logger.debug("Internet connection changed to disconnected...")
    {:noreply, state, 5_000}
  end

  @impl true
  def handle_info({VintageNet, ["connection"], _old_value, new_value, _meta}, state) do
    Logger.debug("Internet connection status changed to #{inspect(new_value)}.")
    {:noreply, state}
  end

  @impl true
  def handle_info(:timeout, state) do
    if wizard_available?() do
      {:noreply, state, {:continue, :try_wizard}}
    else
      {:noreply, state}
    end
  end

  defp wizard_available?() do
    0 !=
      :code.get_path()
      |> Enum.map(&List.to_string/1)
      |> Enum.filter(fn path -> path =~ ~r/vintage_net_wizard/ end)
      |> length
  end

  ## Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
end
