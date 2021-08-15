defmodule ContainerLib.Docker.Client do
  require Logger

  # https://elixirforum.com/t/how-to-send-a-http-request-through-an-unix-socket/35776/6
  defstruct status: 0, headers: [], body: "", stream: false

  alias ContainerLib.Docker.Client, as: D

  @version Mix.Project.config()[:version]

  @doc """
  Sends an HTTP request with the specified method, path and body data to the
  docker daemon.

  Valid options are:
    :target - the target to send the request to, either {:local, "/path/to/unix.socket"} or
              {host, port} with host a valid :gen_tcp host (e.g. {127, 0, 0, 1})
    :stream - returns an Elixir `Stream` for chunked responses instead of the body as binary

  ## Examples

      iex> ContainerLib.Docker.Client.request("GET", "/containers/json")
      {:ok, %ContainerLib.Docker.Client{status: 200}, []}

      iex> ContainerLib.Docker.Client.request("POST", "/containers/abc/attach?stream=1&stdin=1&stdout=1")
      {:stream, %ContainerLib.Docker.Client{}, _socket}

  ## Pro-Tip

  You can use `socat -d -v -d TCP-L:2375,fork UNIX:/var/run/docker.sock` to proxy requests
  to the docker daemon over TCP and use `DOCKER_HOST=tcp://127.0.0.1:2376 docker --args` to
  view what the docker cli is doing.

  """
  def request(method, path, data \\ "", opts \\ []) do
    target = Keyword.get(opts, :target, {:local, "/var/run/docker.sock"})

    recv_options = %D{stream: Keyword.get(opts, :stream, false)}

    {:ok, socket} =
      case target do
        {:local, _unix_sock} ->
          :gen_tcp.connect(target, 0, [
            :binary,
            {:active, false},
            {:packet, :http_bin}
          ])

        {host, port} ->
          :gen_tcp.connect(host, port, [
            :binary,
            {:active, false},
            {:packet, :http_bin}
          ])
      end

    Logger.debug("sending #{inspect(path)}: #{inspect(data)}")

    case data do
      %{} ->
        body = Jason.encode!(data)

        :gen_tcp.send(
          socket,
          """
          #{method} #{path} HTTP/1.1\r
          Host: #{:net_adm.localhost()}\r
          User-Agent: elixir_container_lib/#{@version}\r
          Content-Length: #{byte_size(body)}\r
          Content-Type: application/json\r
          \r
          #{body}
          """
        )

      "" ->
        :gen_tcp.send(
          socket,
          """
          #{method} #{path} HTTP/1.1\r
          Host: #{:net_adm.localhost()}\r
          User-Agent: elixir_container_lib/#{@version}\r
          \r
          #{data}
          """
        )
    end

    do_recv(socket, recv_options)
  end

  defp do_recv(socket, resp),
    do: do_recv(socket, :gen_tcp.recv(socket, 0, 5000), resp)

  defp do_recv(socket, {:ok, {:http_response, {1, 1}, code, _}}, resp) do
    do_recv(socket, :gen_tcp.recv(socket, 0, 5000), %D{resp | status: code})
  end

  defp do_recv(socket, {:ok, {:http_header, _, h, _, v}}, resp) do
    do_recv(socket, :gen_tcp.recv(socket, 0, 5000), %D{resp | headers: [{h, v} | resp.headers]})
  end

  defp do_recv(socket, {:ok, :http_eoh}, resp = %D{stream: true}) do
    case :proplists.get_value(:"Transfer-Encoding", resp.headers) do
      "chunked" -> {:ok, resp, create_stream(socket)}
      _other -> {:error, "cannot stream without Transfer-Encoding: chunked"}
    end
  end

  defp do_recv(socket, {:ok, :http_eoh}, resp) do
    Logger.debug("#{inspect(resp)}")
    # Now we only have body left.
    # Depending on headers here you may want to do different things.
    # The response might be chunked, or upgraded in case you have attached to the container
    # Now I can receive the response. Because of `{:active, false}` I need to explicitly ask for data,
    # otherwise it gets send to the process as messages.
    case :proplists.get_value(:"Content-Type", resp.headers) do
      # Return the socket for bi-directional communication
      "application/vnd.docker.raw-stream" ->
        Logger.debug("it's a stream")
        {:stream, resp, socket}

      "application/json" ->
        with {:ok, data} <- read_body(socket, resp) do
          Logger.debug("got json response: #{inspect(data)}")
          {:ok, resp, Jason.decode!(data)}
        end

      other ->
        Logger.debug("unexpected content type: #{other}")
        {:ok, resp, read_body(socket, resp)}
    end
  end

  defp read_body(socket, resp) do
    case :proplists.get_value(:"Content-Length", resp.headers) do
      :undefined ->
        # No content length. Checked if chunked
        case :proplists.get_value(:"Transfer-Encoding", resp.headers) do
          "chunked" -> read_chunked_body(socket, resp)
          # No body
          _ -> ""
        end

      content_length ->
        bytes_to_read = String.to_integer(content_length)
        # No longer line based http, just read data
        :inet.setopts(socket, [{:packet, :raw}])
        :gen_tcp.recv(socket, bytes_to_read, 5000)
    end
  end

  defp read_chunked_body(socket, resp), do: read_chunked_body(socket, resp, [])

  defp read_chunked_body(socket, resp, acc) do
    :inet.setopts(socket, [{:packet, :line}])

    case :gen_tcp.recv(socket, 0, 5000) do
      {:ok, length} ->
        length = String.trim_trailing(length, "\r\n") |> String.to_integer(16)

        if length == 0 do
          {:ok, :erlang.iolist_to_binary(Enum.reverse(acc))}
        else
          :inet.setopts(socket, [{:packet, :raw}])
          {:ok, data} = :gen_tcp.recv(socket, length, 5000)
          :gen_tcp.recv(socket, 2, 5000)
          read_chunked_body(socket, resp, [data | acc])
        end

      other ->
        {:error, other}
    end
  end

  # creates an Elixir `Stream` for the chunked response
  defp create_stream(socket) do
    Stream.resource(
      fn -> socket end,
      fn socket ->
        :inet.setopts(socket, [{:packet, :line}])

        case :gen_tcp.recv(socket, 0, 5000) do
          {:ok, length} ->
            length = String.trim_trailing(length, "\r\n") |> String.to_integer(16)

            if length == 0 do
              {:halt, socket}
            else
              :inet.setopts(socket, [{:packet, :raw}])
              {:ok, data} = :gen_tcp.recv(socket, length, 5000)
              :gen_tcp.recv(socket, 2, 5000)
              {[data], socket}
            end

          _other ->
            {:halt, {:error, socket}}
        end
      end,
      fn _socket -> nil end
    )
  end

  # Reads from tty. In case of non tty you need to read
  # {:packet, :raw} and decode as described under Stream Format here: https://docs.docker.com/engine/api/v1.40/#operation/ContainerAttach
  # For now just read lines from TTY or timeout after 5 seconds if nothing to be read
  # This requires an attached socket:
  # {:stream, _, socket} = request("POST", "/containers/abc/attach?stream=1&stdin=1&stdout=1")
  # read_stream(socket)
  def read_stream(socket) do
    :inet.setopts(socket, [{:packet, :line}])
    :gen_tcp.recv(socket, 0, 5000)
  end

  # Writes to attached container
  # This requires an attached socket:
  # {:stream, _, socket} = request("POST", "/containers/abc/attach?stream=1&stdin=1&stdout=1")
  # write_stream(socket, "echo \"Hello World\"\r\n")
  # read_stream(socket)
  def write_stream(socket, data) do
    :gen_tcp.send(socket, data)
  end
end
