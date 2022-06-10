defmodule ContainerLib.Docker.Containers do
  @moduledoc """
  Functions for managing docker containers.
  """

  defstruct [
    :id,
    :name,
    :image,
    :entrypoint,
    :command,
    hostname: "",
    user: "",
    working_dir: "",
    remove: false,
    volumes: %{},
    ports: %{},
    environment: %{},
    host_config: %{"network_mode" => "default"}
  ]

  require Logger

  import ContainerLib.Docker, only: [request: 2, request: 3]
  alias ContainerLib.Docker.Containers, as: Container
  alias ContainerLib.Docker.LogParser

  @doc """
  Lists the docker images.

  Valid options are:
    - `:all` boolean (default false)
    - `:digests` boolean (default false)
    - `:filters` json

  See https://docs.docker.com/engine/api/v1.40/#operation/ImageList
  """
  def list(opts \\ []) do
    request("GET", "/containers/json", query: opts)
  end

  @doc """
  Creates a new container from the specified container configuration.
  Fetches the image if it does not exist.

  See `ContainerLib.Container` for the container specification.
  """
  def create(%Container{} = container, name \\ nil) do
    # only send name if it is set
    query = if not is_nil(name), do: [name: name], else: []

    container
    |> to_docker_post()
    |> then(fn data ->
      case request("POST", "/containers/create", body: data, query: query) do
        {:ok, %ContainerLib.Docker.Client{status: 201}, %{"Id" => id}} ->
          {:ok, id}

        {:ok, %ContainerLib.Docker.Client{status: 404}, %{"message" => "No such image:" <> _}} ->
          fetch_and_create(container)

        other ->
          {:error, {:unexpected_response, other}}
      end
    end)
  end

  defp fetch_and_create(%Container{image: image} = container) do
    with {:ok, _status} <- ContainerLib.Docker.Images.create(image) do
      create(container)
    end
  end

  @doc """
  Return low-level information about a container.

  Valid options are:
    - `:size` boolean (default false)

  See https://docs.docker.com/engine/api/v1.40/#operation/ContainerInspect
  """
  def get(id) do
    request("GET", "/containers/#{id}/json")
  end

  @doc """
  List processes running inside a container.

  Valid options are:
    - `:ps_args` string (default "-ef")

  See https://docs.docker.com/engine/api/v1.40/#operation/ContainerTop
  """
  def top(id, opts \\ []) do
    request("GET", "/containers/#{id}/top", query: opts)
  end

  @doc """
  Get stdout and stderr logs from a container.

  Valid options are:
    - `:stdout` boolean (default true)
    - `:stderr` boolean (default false)
    - `:timestamps` boolean (default false)
    - `:follow` boolean (default false)
    - `:tail` string (default "all")
    - `:since` string (default 0)
    - `:until` string (default 0)


  Returns a {:ok, `Stream`} or {:error, reason}.

  See https://docs.docker.com/engine/api/v1.40/#operation/ContainerLogs
  """
  def logs(id, opts \\ []) do
    opts = Keyword.merge([stdout: true], opts)

    with {:ok, %{status: 200}, stream} <-
           request("GET", "/containers/#{id}/logs", query: opts, request_opts: [stream: true]) do
      stream =
        stream
        |> Stream.transform(<<>>, fn data, acc ->
          # docker sends the stream in the format specified in the config
          # but still with HTTP chunked encoding. So we sadly cannot use the
          # raw TCP stream an always receive chunks with the size specified
          # in the header...
          #
          # "Note that unlike the attach endpoint, the logs endpoint
          #  does not upgrade the connection and does not set Content-Type."
          # see https://docs.docker.com/engine/api/v1.40/#operation/ContainerLogs
          case LogParser.parse_logs(acc <> data) do
            {:done, logs} -> {logs, <<>>}
            {:partial, logs, acc} -> {logs, acc}
          end
        end)
        |> Stream.each(fn {type, line} ->
          # we could remove this, but for debugging it is nice to have
          log_type = LogParser.log_type(type)
          Logger.debug("[#{log_type}]: #{inspect(line)}")
        end)

      {:ok, stream}
    else
      other -> {:error, {:invalid_response, other}}
    end
  end

  @doc """
  Starts the specified container.

  See https://docs.docker.com/engine/api/v1.40/#operation/ContainerStart
  """
  def start(id) do
    request("POST", "/containers/#{id}/start")
  end

  @doc """
  Stops the specified container.

  See https://docs.docker.com/engine/api/v1.40/#operation/ContainerStop
  """
  def stop(id) do
    request("POST", "/containers/#{id}/stop")
  end

  @doc """
  Restarts the specified container.

  See https://docs.docker.com/engine/api/v1.40/#operation/ContainerRestart
  """
  def restart(id) do
    request("POST", "/containers/#{id}/restart")
  end

  @doc """
  Pauses the specified container.

  See https://docs.docker.com/engine/api/v1.40/#operation/ContainerPause
  """
  def pause(id) do
    request("POST", "/containers/#{id}/pause")
  end

  @doc """
  Resumes the specified container.

  See https://docs.docker.com/engine/api/v1.40/#operation/ContainerUnpause
  """
  def unpause(id) do
    request("POST", "/containers/#{id}/unpause")
  end

  @doc """
  Kills the specified container.

  See https://docs.docker.com/engine/api/v1.40/#operation/ContainerKill
  """
  def kill(id, signal \\ "SIGKILL") do
    request("POST", "/containers/#{id}/kill", query: [signal: signal])
  end

  @doc """
  Waits for the specified container to reach the given condition.

  See https://docs.docker.com/engine/api/v1.40/#operation/ContainerWait
  """
  def wait(id, condition \\ "not-running") do
    request("POST", "/containers/#{id}/wait", query: [condition: condition])
  end

  @doc """
  Deletes the specified container.

  Valid options are:
    - `:v` boolean (default false)
    - `:force` boolean (default false)
    - `:link` boolean (default false)

  See https://docs.docker.com/engine/api/v1.40/#operation/ContainerDelete
  """
  def delete(id, opts \\ []) do
    request("DELETE", "/containers/#{id}", query: opts)
  end

  @doc """
  Prunes all stopped containers.

  Valid options are:
    - `:filters` json encoded map (default {})

  See https://docs.docker.com/engine/api/v1.40/#operation/ContainerPrune
  """
  def prune(opts \\ []) do
    request("POST", "/containers/prune", query: opts)
  end

  defp to_docker_post(%Container{} = conf) do
    %{
      "Hostname" => conf.hostname,
      "User" => conf.user,
      "Entrypoint" => conf.entrypoint,
      "AttachStdin" => conf.remove,
      "Env" => format_environment(conf.environment),
      "Cmd" => format_command(conf.command),
      "Image" => conf.image,
      "Volumes" => map_empty_map(conf.volumes, 1),
      "WorkingDir" => conf.working_dir,
      "ExposedPorts" => format_ports(conf.ports),
      "NetworkDisabled" => Map.get(conf.host_config, "network_mode") == "none",
      "HostConfig" => format_host_config(conf.host_config)
    }
  end

  defp format_environment(nil), do: []

  defp format_environment(env = %{}) do
    Enum.map(env, &(elem(&1, 0) <> "=" <> elem(&1, 1)))
  end

  defp format_command(nil), do: nil

  defp format_command(command), do: OptionParser.split(command)

  defp format_ports(nil), do: %{}

  defp format_ports(ports = %{}) do
    ports
    |> Map.values()
    |> Enum.map(&port_to_tuple/1)
    |> map_empty_map(0)
  end

  # defp format_volumes(nil), do: nil

  # defp format_volumes(volumes = %{}) do
  #   volumes |> Enum.map(&(to_string(elem(&1, 0)) <> ":" <> elem(&1, 1)))
  # end

  defp format_host_config(nil), do: %{}

  defp format_host_config(host_config) do
    host_config
    |> Enum.map(fn {key, value} -> {titlecase(key), value} end)
    |> Enum.into(%{})
  end

  # Takes a port string, either a single port or : deliminated pair,
  # and turns it into a two-element tuple.
  defp port_to_tuple(port) when is_binary(port) do
    port |> String.split(":") |> port_to_tuple
  end

  defp port_to_tuple([container_port, host_port]) do
    {port_protocol(container_port), host_port}
  end

  defp port_to_tuple([port]) do
    host_port = port |> String.split("/") |> List.first()
    {port_protocol(port), host_port}
  end

  defp port_protocol([port, protocol]), do: port <> "/" <> protocol
  defp port_protocol([port]), do: port <> "/tcp"

  defp port_protocol(port) do
    port
    |> String.split("/")
    |> port_protocol
  end

  defp map_empty_map(nil, _), do: %{}

  defp map_empty_map(dict, element) do
    dict
    |> Enum.map(&{elem(&1, element), %{}})
    |> Enum.into(%{})
  end

  defp titlecase(value) when is_atom(value), do: value |> to_string |> titlecase
  defp titlecase(value) when is_binary(value), do: value |> String.split("_") |> titlecase

  defp titlecase(words) when is_list(words) do
    words
    |> Enum.map(&String.capitalize/1)
    |> Enum.join()
  end
end
