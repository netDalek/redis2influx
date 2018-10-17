defmodule Redis2influx.Influx do
  @moduledoc false

  use Instream.Connection, otp_app: :redis2influx
end
