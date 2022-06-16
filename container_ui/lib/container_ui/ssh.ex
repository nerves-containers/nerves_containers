defmodule ContainerUI.DockerExecSSH do
  @behaviour :ssh_server_channel

  def init(args) do
    id = "214fe8de4e18"
    Process.put(:docker_socket, Application.fetch_env!(:container_ui, :docker_socket))
    {:ok, %{container: nil, exec_sock: nil, exec_id: nil, cid: nil, cm: nil, pty: nil}}
  end

  @impl true
  def handle_msg({:tcp, _tcp_socket, data}, state = %{cm: cm, cid: channel_id}) do
    IO.inspect(data, label: "sending to ssh socket")
    :ssh_connection.send(cm, channel_id, data)
    {:ok, state}
  end

  @impl true
  def handle_msg({:tcp_closed, _tcp_socket}, state = %{cm: cm, cid: channel_id}) do
    {:stop, channel_id, state}
  end

  def handle_msg({:ssh_channel_up, channel_id, connection_manager}, state) do
    IO.puts("ssh up")
    {:ok, %{state | cid: channel_id, cm: connection_manager}}
  end

  def handle_msg(msg, state) do
    IO.inspect(msg, label: "the msg")
    {:ok, state}
  end

  def handle_ssh_msg({:ssh_cm, cm, {:pty, _, _, pty} = msg}, state = %{cm: cm}) do
    IO.inspect(msg, label: "pty", limit: :infinity)
    {:ok, %{state | pty: pty}}
  end

  def handle_ssh_msg({:ssh_cm, cm, {:env, _, _, key, value}}, state = %{cm: cm}) do
    IO.puts(inspect("#{key}=#{value}"))
    {:ok, state}
  end

  def handle_ssh_msg({:ssh_cm, cm, {:shell, _, value}}, state = %{cm: cm}) do
    IO.puts("shell: " <> inspect(value))
    {:ok, state}
  end

  def handle_ssh_msg(
        {:ssh_cm, cm, {:window_change, _, width, height, _, _} = msg},
        state = %{exec_id: exec_id, cm: cm, cid: cid}
      ) do
    IO.inspect(msg, label: "window_change")

    spawn(fn ->
      Process.put(:docker_socket, Application.fetch_env!(:container_ui, :docker_socket))
      ContainerLib.Docker.Exec.resize(exec_id, w: width, h: height)
    end)

    {:ok, state}
  end

  def handle_ssh_msg({:ssh_cm, cm, {:exec, _, _, arg}}, state = %{cid: cid, cm: cm, pty: nil}) do
    :ssh_connection.send(cm, cid, "No pseudo-tty allocated! Try connection with -tt.\n")

    {:stop, cid, state}
  end

  def handle_ssh_msg(
        {:ssh_cm, cm, {:data, _, _, data}},
        state = %{exec_sock: exec_sock, cm: cm, cid: cid}
      )
      when not is_nil(exec_sock) do
    IO.puts("data: " <> inspect(data))
    :ok = :gen_tcp.send(exec_sock, data)
    {:ok, state}
  end

  def handle_ssh_msg(
        {:ssh_cm, cm, {:exec, _, _, arg}},
        state = %{container: nil, cid: channel_id, pty: {_term, width, height, _, _, _}}
      ) do
    IO.puts("data: " <> inspect(arg))
    id = List.to_string(arg)

    with {:ok, %{status: 200}, container} <- ContainerLib.Docker.Containers.get(id),
         {:ok, id} <-
           ContainerLib.Docker.Exec.create(
             container["Id"],
             %ContainerLib.Docker.Exec{
               cmd: ["/bin/sh"],
               attach_stdin: true,
               attach_stdout: true,
               attach_stderr: true,
               detach_keys: "",
               tty: true,
               env: []
             }
           ),
         {:stream, _client, tcp_sock} <-
           ContainerLib.Docker.Exec.start(id, detach: false, tty: true),
         _ <- ContainerLib.Docker.Exec.resize(id, w: width, h: height),
         :ok <-
           :inet.setopts(tcp_sock, active: true, packet: :raw) do
      {:ok, %{state | container: container, exec_id: id, exec_sock: tcp_sock}}
    else
      _ -> {:stop, channel_id, state}
    end
  end

  def handle_ssh_msg({:ssh_cm, _, {:eof, _}}, state = %{exec_id: exec_id, cid: cid}) do
    {:ok, _, %{"Pid" => pid}} = ContainerLib.Docker.Exec.get(exec_id)
    System.cmd("kill", ["-9", pid]) |> IO.inspect()

    {:stop, cid, state}
  end

  def handle_ssh_msg(arg0, state) do
    IO.inspect(arg0, label: "the arg")
    IO.inspect(state, label: "the state")
    {:ok, state}
  end
end
