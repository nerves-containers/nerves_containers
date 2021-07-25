defmodule ContainerLib.Docker.Networks do
  @moduledoc """
  Functions for managing docker networks.
  """

  defstruct [
    :name,
    :ipam,
    :options,
    driver: "bridge",
    enable_ipv6: true,
    internal: true,
    labels: nil,
    attachable: false
  ]

  import ContainerLib.Docker, only: [request: 2, request: 3]
  alias ContainerLib.Docker.Networks, as: N

  @doc """
  Lists all networks.

  See https://docs.docker.com/engine/api/v1.40/#operation/NetworkList
  """
  def list(opts \\ []) do
    request("GET", "/networks", query: opts)
  end

  @doc """
  Gets detailed informnation about the specified network.

  See https://docs.docker.com/engine/api/v1.40/#operation/NetworkInspect
  """
  def get(id_or_name) do
    request("GET", "/networks/#{id_or_name}")
  end

  @doc """
  Removes the specified network.

  See https://docs.docker.com/engine/api/v1.40/#operation/NetworkDelete
  """
  def delete(id_or_name) do
    request("DELETE", "/networks/#{id_or_name}")
  end

  @doc """
  Creates a network from the specified configuration.

  See https://docs.docker.com/engine/api/v1.40/#operation/NetworkCreate
  """
  def create(network = %N{}) do
    network
    |> to_docker_post()
    |> then(fn data -> request("POST", "/networks/create", body: data) end)
  end

  defp to_docker_post(conf = %N{}) do
    %{
      "Name" => conf.name,
      "CheckDuplicate" => false,
      "Driver" => conf.driver,
      "EnableIPv6" => conf.enable_ipv6,
      "IPAM" => conf.ipam,
      "Internal" => conf.internal,
      "Attachable" => conf.attachable,
      "Options" => conf.options,
      "Labels" => conf.labels
    }
  end

  @doc """
  Deletes unused networks.

  See https://docs.docker.com/engine/api/v1.40/#operation/NetworkPrune
  """
  def prune(opts \\ []) do
    request("POST", "/networks/prune", query: opts)
  end
end
