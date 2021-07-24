import Config

# Add configuration that is only needed when running on the host here.
config :container_manager,
  docker_socket: {:local, "/var/run/docker.sock"}
