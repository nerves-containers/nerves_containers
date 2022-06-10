defmodule ContainerUIWeb.ContainerLive do
  use ContainerUIWeb, :live_view

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      with {:ok, %{status: 200}, container} <- ContainerLib.Docker.Containers.get(id) do
        {:ok, assign(socket, container: container, error: false)}
      else
        _other -> {:ok, assign(socket, error: true)}
      end
    else
      {:ok, assign(socket, container: %{}, error: false)}
    end
  end

  @impl true
  def handle_event("init_exec", _value, socket) do
    with {:ok, id} <-
           ContainerLib.Docker.Exec.create(
             socket.assigns.container["Id"],
             %ContainerLib.Docker.Exec{
               cmd: ["/bin/sh"],
               attach_stdin: true,
               attach_stdout: true,
               attach_stderr: true,
               detach_keys: "",
               tty: true,
               env: []
             }
           ),
         {:stream, _client, tcp_sock} <-
           ContainerLib.Docker.Exec.start(id, detach: false, tty: true),
         :ok <- ContainerUI.ExecMonitor.monitor(id) do
      :inet.setopts(tcp_sock, active: true, packet: :raw) |> IO.inspect(label: "set to active")
      {:noreply, assign(socket, exec_id: id, exec_sock: tcp_sock)}
    else
      _other -> {:noreply, assign(socket, error: true)}
    end
  end

  @impl true
  def handle_event("input", value, socket) do
    :ok = :gen_tcp.send(socket.assigns.exec_sock, value)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:tcp, _tcp_socket, data}, socket) do
    {:noreply, push_event(socket, "docker_line", %{"data" => data})}
  end

  @impl true
  def render(assigns) do
    ~H"""
      <h1><%= if @error, do: "Error", else: @container["Name"] %></h1>
      <%= if @error do %>
      <div>
        There was an error loading this container...
      </div>
      <% else %>
        <div phx-hook="Terminal" id={@container["Id"]}></div>
      <% end %>
    """
  end
end
