defmodule NervesContainers.Docker do
  @moduledoc """
  Functions for working with docker.
  """

  @doc """
  Runs a docker command.

  ## Examples

      iex> NervesContainers.Docker.run(["ps"])
      {"CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES\n", 0}

  """
  def run(command_list, opts \\ []) do
    opts = Keyword.put_new(opts, :stderr_to_stdout, true)
    System.cmd("balena-engine", command_list, opts)
  end
end
