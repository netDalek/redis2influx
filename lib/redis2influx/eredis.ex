defmodule Redis2influx.Eredis do
  import Supervisor.Spec
  require Logger
  
  def start_link(args) do
    name = redis_name(args)
    :breaky.start_circuit_breaker(name, {:eredis, :start_link, args})
  end

  def q(args, cmd) do
    name = redis_name(args)
    case :breaky.pid(name) do
      :off ->
        {:error, :no_connection};
      {:ok, pid} ->
        :eredis.q(pid, cmd)
    end
  end

  def child_specs do
    Application.fetch_env!(:redis2influx, :redises)
              |> Map.to_list
              |> Enum.flat_map(fn
                ({_name, map}) when is_map(map) ->
                  Map.values(map)
                ({_name, args}) ->
                  [args]
              end)
              |> Enum.map(fn(args) ->
                worker(Redis2influx.Eredis, [args], [id: redis_name(args)])
              end)
  end

  defp redis_name(args) do
    String.to_atom("#{Kernel.inspect(args)}__redis")
  end
end
