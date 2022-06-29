defmodule Riax.Supervisor do
  use Supervisor

  def start_link(args = [name: name, vnode: _, coverage: _]) do
    Supervisor.start_link(__MODULE__, tl(args), name: name)
  end

  def init([vnode: vnode, coverage: coverage]) do
    children = [
      %{
        id: Riax.VNode_master_worker,
        start: {:riak_core_vnode_master, :start_link, [vnode]},
        type: :worker
      },
      %{
        id: Riax.CoverageSup,
        start: {coverage, :start_link, []},
        restart: :permanent,
        type: :supervisor,
        shutdown: :infinity
      }
    ]

    Supervisor.init(children, strategy: :one_for_one, max_restarts: 5, max_seconds: 10)
  end
end
