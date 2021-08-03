defmodule ContainerLib.Docker.Compose do
  defstruct [
    :services,
    volumes: %{},
    networks: %{}
  ]

  alias ContainerLib.Docker.Compose
  alias ContainerLib.Docker.Containers, as: Container
  alias ContainerLib.Docker.Volumes, as: Volume
  alias ContainerLib.Docker.Networks, as: Network

  def from_file(path) do
    with {:ok, yaml} <- YamlElixir.read_from_file(path) do
      parse(yaml)
    end
  end

  def from_string(yaml) do
    with {:ok, yaml} <- YamlElixir.read_from_string(yaml) do
      parse(yaml)
    end
  end

  def parse(%{"version" => version} = item) do
    {version, _} = Float.parse(version)

    cond do
      version >= 2 and version < 3 -> parse_v2(item)
      true -> {:error, "Unsupported version: #{version}"}
    end
  end

  def parse_v2(%{"services" => services} = item) when is_map(services) do
    %Compose{
      services:
        Enum.map(services, fn {key, value} ->
          %Container{
            image: Map.get(value, "image"),
            name: Map.get(value, "container_name", key),
            entrypoint: Map.get(value, "entrypoint"),
            command: Map.get(value, "command"),
            hostname: Map.get(value, "hostname"),
            user: Map.get(value, "user"),
            working_dir: Map.get(value, "working_dir"),
            remove: false,
            ports: Map.get(value, "ports"),
            environment: Map.get(value, "environment"),
            host_config: %{
              privileged: Map.get(value, "privileged", false),
              binds: Map.get(value, "volumes")
            }
          }
        end),
      volumes:
        Map.get(item, "volumes", %{})
        |> Enum.map(fn
          {key, nil} ->
            %Volume{name: key}

          {key, value} ->
            %Volume{
              name: key,
              driver: Map.get(value, "driver"),
              driver_opts: Map.get(value, "driver_opts")
            }
        end),
      networks:
        Map.get(item, "networks", %{})
        |> Enum.map(fn {key, value} ->
          %Network{
            name: Map.get(value, "name", key),
            ipam: Map.get(value, "ipam"),
            driver: Map.get(value, "driver"),
            options: Map.get(value, "driver_opts"),
            enable_ipv6: Map.get(value, "enable_ipv6", true),
            internal: Map.get(value, "internal", false),
            labels: Map.get(value, "labels")
          }
        end)
    }
  end
end
