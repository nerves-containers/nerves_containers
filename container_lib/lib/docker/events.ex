defmodule ContainerLib.Docker.Events do
  @moduledoc """
  Functions for attaching to docker events.
  """

  import ContainerLib.Docker, only: [request: 3]

  @doc """
  Stream real-time events from the server.

  See https://docs.docker.com/engine/api/v1.40/#operation/SystemEvents
  """
  def get(opts \\ []) do
    request("GET", "/events", query: opts)
  end
end
