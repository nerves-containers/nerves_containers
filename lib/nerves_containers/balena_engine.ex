defmodule NervesContainers.BalenaEngine do
  def child_spec(_) do
    %{
      id: __MODULE__,
      start:
        {MuonTrap.Daemon, :start_link,
         [
           "balena-engine-daemon",
           [
             "--data-root",
             "/root/balena",
             "--experimental"
           ],
           [log_output: :info, stderr_to_stdout: true]
         ]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end
end
