defmodule ContainerUIWeb.PageController do
  use ContainerUIWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
