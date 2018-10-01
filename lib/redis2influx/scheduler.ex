defmodule Redis2influx.Scheduler do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [], [])
  end

  def init([]) do
    schedule_work(0)
    {:ok, %{}}
  end

  def handle_info(:work, state) do
    Redis2influx.Harvester.check
    interval = Application.fetch_env!(:redis2influx, :interval)
    schedule_work(interval)
    {:noreply, state}
  end

  defp schedule_work(interval) do
    Process.send_after(self(), :work, interval*1000)
  end
end
