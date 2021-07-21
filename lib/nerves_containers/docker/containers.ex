defmodule NervesContainers.Docker.Containers do
  @moduledoc """
  Functions for managing containers.
  """

  import NervesContainers.Docker, only: [request: 3]

  def list(opts \\ []) do
    request("GET", "/containers/json", query: opts)
  end
end
