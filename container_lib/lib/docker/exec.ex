defmodule ContainerLib.Docker.Exec do
  @moduledoc """
  Functions for executing commands inside a container.
  """

  @enforce_keys [:cmd]
  defstruct [
    :cmd,
    attach_stdin: true,
    attach_stdout: true,
    attach_stderr: false,
    detach_keys: "",
    tty: false,
    env: []
  ]

  import ContainerLib.Docker, only: [request: 2, request: 3]
  alias ContainerLib.Docker.Exec

  @doc """
  Creates an exec instance for the given container.

  Returns the exec id.

  See https://docs.docker.com/engine/api/v1.40/#operation/ContainerExec
  """
  def create(id, exec = %Exec{}) do
    with {:ok, %{status: 201}, %{"Id" => id}} <-
           exec
           |> to_docker_post()
           |> then(fn data -> request("POST", "/containers/#{id}/exec", body: data) end) do
      {:ok, id}
    end
  end

  defp to_docker_post(conf = %Exec{}) do
    %{
      "Cmd" => conf.cmd,
      "AttachStdin" => conf.attach_stdin,
      "AttachStdout" => conf.attach_stdout,
      "AttachStderr" => conf.attach_stderr,
      "DetachKeys" => conf.detach_keys,
      "Tty" => conf.tty,
      "Env" => conf.env
    }
  end

  @doc """
  Return low-level information about an exec instance.

  See https://docs.docker.com/engine/api/v1.40/#operation/ExecInspect
  """
  def get(id) do
    request("GET", "/exec/#{id}/json")
  end

  @doc """
  Starts the specified exec instance.

  See https://docs.docker.com/engine/api/v1.40/#operation/ExecStart
  """
  def start(id, opts \\ []) do
    detach = Keyword.get(opts, :detach, false)
    tty = Keyword.get(opts, :tty, false)

    request("POST", "/exec/#{id}/start",
      body: %{
        "Detach" => detach,
        "Tty" => tty
      }
    )
  end
end
