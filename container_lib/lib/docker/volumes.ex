defmodule ContainerLib.Docker.Volumes do
  @moduledoc """
  Functions for managing docker volumes.
  """

  defstruct [
    :name,
    :labels,
    :driver,
    :driver_opts
  ]

  import ContainerLib.Docker, only: [request: 2, request: 3]
  alias ContainerLib.Docker.Volumes, as: V

  @doc """
  Lists all volumes.

  See https://docs.docker.com/engine/api/v1.40/#operation/VolumeList
  """
  def list(opts \\ []) do
    request("GET", "/volumes", query: opts)
  end

  @doc """
  Gets detailed informnation about the specified volume.

  See https://docs.docker.com/engine/api/v1.40/#operation/VolumeInspect
  """
  def get(id_or_name) do
    request("GET", "/volumes/#{id_or_name}")
  end

  @doc """
  Creates a new volume.

  See https://docs.docker.com/engine/api/v1.40/#operation/VolumeCreate
  """
  def create(volume = %V{}) do
    volume
    |> to_docker_post()
    |> then(fn data -> request("POST", "/volumes/create", body: data) end)
  end

  defp to_docker_post(conf = %V{}) do
    %{
      "Name" => conf.name,
      "Driver" => conf.driver,
      "DriverOpts" => conf.driver_opts,
      "Labels" => conf.labels
    }
  end

  @doc """
  Delete the specified volume.

  See https://docs.docker.com/engine/api/v1.40/#operation/VolumeDelete
  """
  def delete(id_or_name) do
    request("DELETE", "/volumes/#{id_or_name}")
  end

  @doc """
  Removes unused volumes.

  See https://docs.docker.com/engine/api/v1.40/#operation/VolumePrune
  """
  def prune(opts \\ []) do
    request("POST", "/volumes/prune", query: opts)
  end
end
