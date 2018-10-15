defmodule Redis2influx.Eredis do
  import Supervisor.Spec
  require Logger
  use GenServer

  @reconnect_interval 1000

  def start_link(args) do
    name = redis_name(args)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def q(args, cmd) do
    name = redis_name(args)
    GenServer.call(name, {:q, cmd})
  end

  def child_specs do
    Application.fetch_env!(:redis2influx, :redises)
    |> Map.to_list()
    |> Enum.flat_map(fn
      {_name, map} when is_map(map) ->
        Map.values(map)

      {_name, args} ->
        [args]
    end)
    |> Enum.map(fn args ->
      worker(Redis2influx.Eredis, [args], id: redis_name(args))
    end)
  end

  @impl true
  def init(args) do
    :erlang.send_after(0, self(), :connect)
    {:ok, %{args: args, redis: nil}}
  end

  @impl true
  def handle_call({:q, _cmd}, _from, %{redis: nil} = state) do
    {:reply, {:error, :no_connection}, state}
  end

  @impl true
  def handle_call({:q, cmd}, _from, state) do
    {:reply, :eredis_sync.q(state.redis, cmd), state}
  end

  @impl true
  def handle_info(:connect, state) do
    case :erlang.apply(:eredis_sync, :connect_db, state.args) do
      {:ok, conn} ->
        {:noreply, %{state | redis: conn}}

      error ->
        Logger.error("redis #{inspect(state.args)} error #{inspect(error)}")
        :erlang.send_after(@reconnect_interval, self(), :connect)
        {:noreply, state}
    end
  end

  defp redis_name(args) do
    String.to_atom("#{Kernel.inspect(args)}__redis")
  end
end
