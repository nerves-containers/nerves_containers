defmodule ContainerLib.Docker do
  @moduledoc """
  Functions for interacting with a Docker Daemon using the [Docker Engine API](https://docs.docker.com/engine/api/).
  """

  alias ContainerLib.Docker.Client

  def api_version(), do: "v1.40"

  def socket() do
    Process.get(:docker_socket, {:local, "/var/run/docker.sock"})
  end

  def request(method, path, opts \\ []) do
    query =
      Keyword.get(opts, :query, [])
      |> URI.encode_query(:rfc3986)

    ignore_version = Keyword.get(opts, :no_version, false)
    body = Keyword.get(opts, :body, "")

    cond do
      String.starts_with?(path, "/v1.") or ignore_version ->
        Client.request(method, "#{path}?#{query}", body, socket())

      true ->
        Client.request(method, "/#{api_version()}#{path}?#{query}", body, socket())
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
