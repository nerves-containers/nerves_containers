defmodule ContainerLib.Docker.Images do
  @moduledoc """
  Functions for managing docker images.
  """

  require Logger

  import ContainerLib.Docker, only: [request: 2, request: 3]

  @doc """
  Lists all images.

  Valid options are:
    - `:all` (`true` or `false`)
    - `:filters` json encoded map
    - `:digests` (`true` or `false`)

  See https://docs.docker.com/engine/api/v1.40/#operation/ImageList
  """
  def list(opts \\ []) do
    request("GET", "/images/json", query: opts)
  end

  @doc """
  Create an image by either pulling it from a registry.

  See https://docs.docker.com/engine/api/v1.40/#operation/ImageCreate
  """
  def create(image, opts \\ []) when is_binary(image) and is_list(opts) do
    {image, tag} = split_image(image)

    opts = Keyword.merge(opts, fromImage: image, tag: tag)

    with {:ok, %ContainerLib.Docker.Client{status: 200}, stream} <-
           request("POST", "/images/create", query: opts, request_opts: [stream: true]) do
      output =
        stream
        |> Stream.flat_map(fn chunk ->
          # docker can send multiple lines in one chunk
          # we need to split them into separate lines
          String.split(chunk, "\r\n", trim: true)
        end)
        |> Stream.map(fn line -> Jason.decode!(line) end)
        |> Enum.to_list()

      case Enum.find(output, fn
             %{"status" => "Status: Downloaded newer image for" <> _} -> true
             %{"status" => "Status: Image is up to date for" <> _} -> true
             %{"status" => "Status:" <> _} -> true
             _other -> false
           end) do
        nil -> {:error, output}
        status -> {:ok, status}
      end
    end
  end

  defp split_image(image) when is_binary(image) do
    case String.split(image, ":", parts: 2) do
      [image, tag] -> {image, tag}
      [image] -> {image, "latest"}
    end
  end

  @doc """
  Return low-level information about an image.

  See https://docs.docker.com/engine/api/v1.40/#operation/ImageInspect
  """
  def get(id_or_name) do
    request("GET", "/images/#{id_or_name}/json")
  end

  @doc """
  Deletes the specified image.

  See https://docs.docker.com/engine/api/v1.40/#operation/ImageDelete
  """
  def delete(id) do
    request("DELETE", "/images/#{id}")
  end

  @doc """
  Deletes all unused images.

  See https://docs.docker.com/engine/api/v1.40/#operation/ImagePrune
  """
  def prune() do
    request("POST", "/images/prune")
  end
end
