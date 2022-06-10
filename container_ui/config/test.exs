import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :container_ui, ContainerUIWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "1pm+1Hi/Y63h5FT5//yTNb0qMS8Dh7BmsZV3US4afNPowp+IVnXYBB3hac6n32HC",
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
