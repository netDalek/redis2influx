defmodule Redis2influx do
  def interval do
    Application.get_env(:redis2influx, :interval, 60)
  end

  def redis_reconnect_intervals do
    Application.get_env(:redis2influx, :redis_reconnect_intervals, [1000, 5000, 60000, 300000])
  end
end
