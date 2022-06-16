import Config

config :nerves_runtime,
  target: "host"

config :nerves_ssh,
  port: 2221,
  user_dir: File.cwd!(),
  system_dir: File.cwd!(),
  authorized_keys:
    [
      Path.join([System.user_home!(), ".ssh", "id_rsa.pub"]),
      Path.join([System.user_home!(), ".ssh", "id_ecdsa.pub"]),
      Path.join([System.user_home!(), ".ssh", "id_ed25519.pub"])
    ]
    |> Enum.filter(&File.exists?/1)
    |> Enum.map(&File.read!/1)

# Add configuration that is only needed when running on the host here.
config :container_manager,
  docker_socket: {:local, "/var/run/docker.sock"}

# Configures Elixir's Logger
config :logger,
  backends: [:console],
  level: :debug
