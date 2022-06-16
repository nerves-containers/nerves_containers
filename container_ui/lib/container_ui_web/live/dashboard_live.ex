defmodule ContainerUIWeb.DashboardLive do
  use ContainerUIWeb, :live_view

  def mount(_params, _session, socket) do
    Process.put(:docker_socket, Application.fetch_env!(:container_ui, :docker_socket))

    with {:ok, %{status: 200}, containers} <- ContainerLib.Docker.Containers.list(all: true) do
      {:ok, assign(socket, containers: containers, error: false)}
    else
      other -> {:ok, assign(socket, error: true)}
    end
  end

  def format_id(str) do
    String.slice(str, 0, 12)
  end

  def render(assigns) do
    ~H"""
      <h1>Containers</h1>
      <%= if @error do %>
      <div>
        There was an error loading the containers...
      </div>
      <% else %>
      <table>
        <thead>
          <th>ID</th>
          <th>Name</th>
          <th>Status</th>
        </thead>
        <tbody>
          <%= for container <- @containers do %>
            <tr>
              <td><a href={Routes.container_path(@socket, :show, format_id(container["Id"]))}><%= format_id(container["Id"]) %></a></td>
              <td><%= Enum.at(container["Names"], 0) %></td>
              <td><%= container["Status"] %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
      <% end %>
    """
  end
end
