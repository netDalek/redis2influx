defmodule Redis2influx.Scheduler do
  @moduledoc false

  use GenServer

  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [], [])
  end

  def init([]) do
    schedule_work(0)
    {:ok, %{}}
  end

  def handle_info(:work, state) do
    points = Redis2influx.Harvester.check()
    Logger.debug("writing points #{inspect(points)}")

    :ok = %{points: points}
          |> Redis2influx.Influx.write()

    schedule_work(Redis2influx.interval())
    {:noreply, state}
  end

  defp schedule_work(interval) do
    Process.send_after(self(), :work, interval * 1000)
  end
end
