# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

config :container_manager, target: Mix.target()

if Mix.target() == :host or Mix.target() == :"" do
  import_config "host.exs"
else
  import_config "target.exs"
end
