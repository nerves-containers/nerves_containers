defmodule ContainerLib.Container do
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
end
