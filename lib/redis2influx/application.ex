defmodule Redis2influx.Application do
  @moduledoc false

  use Application
  import Supervisor.Spec

  def start(_type, _args) do
    children = Redis2influx.Eredis.child_specs ++ [
      Redis2influx.Influx.child_spec,
      worker(Redis2influx.Scheduler, [], [id: Redis2influx.Scheduler])
    ]

    opts = [strategy: :one_for_one, name: Redis2influx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
