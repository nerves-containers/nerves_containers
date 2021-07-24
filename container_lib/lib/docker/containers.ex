defmodule ContainerLib.Docker.Containers do
  @moduledoc """
  Functions for managing containers.
  """

  import ContainerLib.Docker, only: [request: 3]
  alias ContainerLib.Container

  def list(opts \\ []) do
    request("GET", "/containers/json", query: opts)
  end

  def create(%Container{} = container) do
    container
    |> to_docker_post()
    |> then(fn data -> request("POST", "/containers/create", body: data) end)
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

  def format_environment(nil), do: []

  def format_environment(env = %{}) do
    Enum.map(env, &(elem(&1, 0) <> "=" <> elem(&1, 1)))
  end

  def format_command(nil), do: nil

  def format_command(command), do: OptionParser.split(command)

  def format_ports(nil), do: %{}

  def format_ports(ports = %{}) do
    ports
    |> Map.values()
    |> Enum.map(&port_to_tuple/1)
    |> map_empty_map(0)
  end

  def format_volumes(nil), do: nil

  def format_volumes(volumes = %{}) do
    volumes |> Enum.map(&(to_string(elem(&1, 0)) <> ":" <> elem(&1, 1)))
  end

  def format_host_config(nil), do: %{}

  def format_host_config(host_config) do
    host_config
    |> Enum.map(fn {key, value} -> {titlecase(key), value} end)
    |> Enum.into(%{})
  end

  @doc """
  Takes a port string, either a single port or : deliminated pair,
  and turns it into a two-element tuple.
  """
  def port_to_tuple(port) when is_binary(port) do
    port |> String.split(":") |> port_to_tuple
  end

  def port_to_tuple([container_port, host_port]) do
    {port_protocol(container_port), host_port}
  end

  def port_to_tuple([port]) do
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
