NervesMOTD.print()

# Add Toolshed helpers to the IEx session
use Toolshed

Process.put(:docker_socket, Application.get_env(:container_manager, :docker_socket))
