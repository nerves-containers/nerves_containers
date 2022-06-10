defmodule ContainerUI.ExecMonitor do
  use GenServer

  @impl true
  def init(_) do
    {:ok, %{processes: %{}}}
  end

  @impl true
  def handle_call({:monitor, pid, exec_id}, _from, state) do
    ref = Process.monitor(pid)

    {:reply, :ok,
     update_in(state, [:processes], fn map -> Map.put(map, pid, %{ref: ref, exec_id: exec_id}) end)}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state = %{processes: pidmap}) do
    %{exec_id: exec_id} = Map.fetch!(pidmap, pid)

    with {:ok, %{status: 200}, %{"Pid" => container_pid}} <- ContainerLib.Docker.Exec.get(exec_id) do
      IO.inspect(container_pid, label: "the pid in the container")

      {:noreply,
       state
       |> update_in([:processes], fn map -> Map.delete(map, pid) end)}
    else
      _other ->
        {:noreply,
         state
         |> update_in([:processes], fn map -> Map.delete(map, pid) end)}
    end
  end

  ## Client API ##

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def monitor(exec_id) do
    GenServer.call(__MODULE__, {:monitor, self(), exec_id})
  end
end
