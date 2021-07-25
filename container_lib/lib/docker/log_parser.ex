defmodule ContainerLib.Docker.LogParser do
  def parse_logs(data), do: parse_recursive(data, [])

  defp parse_recursive(<<>>, acc), do: {:done, Enum.reverse(acc)}

  defp parse_recursive(
         <<type::binary-size(1), 0, 0, 0, size::integer-size(32), data::binary-size(size),
           rest::binary()>>,
         acc
       ) do
    parse_recursive(rest, [{type, data} | acc])
  end

  defp parse_recursive(other, acc) do
    {:partial, Enum.reverse(acc), other}
  end

  def log_type(<<0>>), do: "stdin"
  def log_type(<<1>>), do: "stdout"
  def log_type(<<2>>), do: "stderr"
end
