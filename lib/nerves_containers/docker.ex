defmodule NervesContainers.Docker do
  @moduledoc """
  Functions for interacting with a Docker Daemon using the [Docker Engine API](https://docs.docker.com/engine/api/).
  """

  alias NervesContainers.Docker.Client

  def api_version(), do: "v1.40"

  def socket() do
    Application.get_env(:nerves_containers, :docker_socket, {:local, "/var/run/docker.sock"})
  end

  def request(method, path, opts \\ []) do
    query =
      Keyword.get(opts, :query, [])
      |> URI.encode_query(:rfc3986)

    ignore_version = Keyword.get(opts, :no_version, false)

    cond do
      String.starts_with?(path, "/v1.") or ignore_version ->
        Client.request(method, "#{path}?#{query}", socket())

      true ->
        Client.request(method, "/#{api_version()}#{path}?#{query}", socket())
    end
  end

  def info() do
    request("GET", "/info")
  end

  def version() do
    request("GET", "/version", no_version: true)
  end

  def ping() do
    request("GET", "/_ping", no_version: true)
  end

  def events(query \\ []) do
    request("GET", "/events", query: query)
  end

  def df() do
    request("GET", "/system/df")
  end
end
