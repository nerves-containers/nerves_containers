defmodule Mix.Tasks.NervesContainers.PrebuildCompose do
  @moduledoc """
  A task to build a Docker compose archive to run docker compose commands
  without needing network access.

  ## Example

  ```shell
  $ mix nerves_containers.prebuild_compose --platform linux/arm/v7 --output compose.tar
  ```

  Note: to build for different architectures, follow the Docker guide: https://docs.docker.com/build/building/multi-platform/.

  On Linux:

  ```
  $ docker run --privileged --rm tonistiigi/binfmt --install all
  ```
  """

  use Mix.Task

  @shortdoc "Prebuilds a docker archive for docker with the compose plugin."
  def run(args) do
    if !System.find_executable("docker") do
      raise "docker executable is not available on your system!"
    end

    {opts, _, _} = OptionParser.parse(args, strict: [platform: :string, output: :string])

    platform =
      Keyword.get(opts, :platform) ||
        raise "you need to pass the --platform parameter for docker buildx"

    output =
      Keyword.get(opts, :output) ||
        raise "you need to pass the --output parameter (file path) where we'll store the image archive, e.g. priv/compose.tar.gz"

    System.cmd(
      "docker",
      [
        "buildx",
        "build",
        "--platform",
        platform,
        "-t",
        "docker/compose",
        "--output",
        "type=docker,dest=#{output}",
        Application.app_dir(:nerves_containers, "priv/compose")
      ],
      stderr_to_stdout: true
    )
  end
end
