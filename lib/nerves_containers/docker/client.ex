defmodule NervesContainers.Docker.Client do
  # https://elixirforum.com/t/how-to-send-a-http-request-through-an-unix-socket/35776/6
  defstruct status: 0, headers: [], body: ""

  alias NervesContainers.Docker.Client, as: D

  # Send requests to the docker daemon.
  # request("GET", "/containers/json")
  # request("POST", "/containers/abc/attach?stream=1&stdin=1&stdout=1")
  #
  # To post data you need to add a Content-Type and a Content-Length header to the
  # request and then send the data to the socket
  def request(method, path, target \\ {:local, "/var/run/docker.sock"}) do
    {:ok, socket} = :gen_tcp.connect(target, 0, [
      :binary,
      {:active, false},
      {:packet, :http_bin}
    ])
    :gen_tcp.send(socket, "#{method} #{path} HTTP/1.1\r\nHost: #{:net_adm.localhost()}\r\n\r\n")
    do_recv(socket)
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

  def do_recv(socket), do: do_recv(socket, :gen_tcp.recv(socket, 0 , 5000), %D{})

  def do_recv(socket, {:ok, {:http_response, {1,1}, code, _}}, resp) do
    do_recv(socket, :gen_tcp.recv(socket, 0, 5000), %D{resp | status: code})
  end
  def do_recv(socket, {:ok, {:http_header, _, h, _, v}}, resp) do
    do_recv(socket, :gen_tcp.recv(socket, 0, 5000), %D{resp | headers: [{h, v} | resp.headers]})
  end
  def do_recv(socket, {:ok, :http_eoh}, resp) do
    IO.inspect(resp, label: "resp before body")
      # Now we only have body left.
      # # Depending on headers here you may want to do different things.
      # # The response might be chunked, or upgraded in case you have attached to the container
      # # Now I can receive the response. Because of `:active, false} I need to explicitly ask for data, otherwise it gets send to the process as messages.
    case :proplists.get_value(:"Content-Type", resp.headers) do
      "application/vnd.docker.raw-stream" -> {:stream, resp, socket} # Return the socket for bi-directional communication
      "application/json" -> with {:ok, data} <- read_body(socket, resp), do: {:ok, resp, Jason.decode!(data)}
      _ -> {:ok, resp, read_body(socket, resp)}
    end
  end

  def read_body(socket, resp) do
    case :proplists.get_value(:"Content-Length", resp.headers) do
      :undefined ->
        # No content length. Checked if chunked
        case :proplists.get_value(:"Transfer-Encoding", resp.headers) do
          "chunked" -> read_chunked_body(socket, resp)
          _ -> "" # No body
        end
      content_length ->
        bytes_to_read = String.to_integer(content_length)
        :inet.setopts(socket, [{:packet, :raw}]) # No longer line based http, just read data
        case :gen_tcp.recv(socket, bytes_to_read, 5000) do
          {:ok, data} ->
            data
          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  def read_chunked_body(socket, resp), do: read_chunked_body(socket, resp, [])

  def read_chunked_body(socket, resp, acc) do
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
end
