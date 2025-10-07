defmodule NervesContainers.Compose do
  @moduledoc """
  Functions for working with docker compose projects.
  """

  require Logger

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :transient,
      shutdown: 500
    }
  end

  def start_link do
    case System.cmd("balena-engine", ["build", "-t", "docker/compose", "."],
           cd: priv_dir("compose")
         ) do
      {result, 0} ->
        Logger.info("Container Manager: Compose image built! Log:\n#{result}")
        :persistent_term.put(__MODULE__, true)
        :ignore

      {error, exit_code} ->
        Logger.error(
          "Container Manager: Error building compose image! Log:\n#{error}\nExit code: #{exit_code}\n\n Trying again in 5 seconds..."
        )

        {:error, error}
    end
  end

  @doc """
  Runs a docker compose command.

  Important: Ensure that the `docker/compose` container was built
  by including `NervesContainers.Compose` in your supervision tree!

  At the moment, this requires an active internet connection, so
  also ensure that `:wait_for_internet` config is not set to false.
  """
  def run(command_list, pwd) do
    if !:persistent_term.get(__MODULE__) do
      raise ArgumentError,
            "compose image was not built. Ensure the NervesContainers.Compose module is part of your supervision tree or check the logs!"
    end

    NervesContainers.Docker.run(
      [
        "run",
        "--rm",
        "-e",
        "HOME=/root",
        "-w",
        pwd,
        "-v",
        "/root/.balena-engine:/root/.docker",
        "-v",
        "/var/run/balena-engine.sock:/var/run/docker.sock",
        "-v",
        pwd <> ":" <> pwd,
        "docker/compose",
        "compose"
      ] ++ command_list
    )
  end

  defp priv_dir(folder) do
    Path.join([Application.app_dir(:nerves_containers), "priv", folder])
  end
end
