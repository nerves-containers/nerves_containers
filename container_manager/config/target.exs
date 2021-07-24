import Config

config :container_manager,
  docker_socket: {:local, "/var/run/balena-engine.sock"}

# Import target specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Uncomment to use target specific configurations

# import_config "#{Mix.target()}.exs"
