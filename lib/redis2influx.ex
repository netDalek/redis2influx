defmodule Redis2influx do
  def interval do
    Application.fetch_env!(:redis2influx, :interval)
  end
end
