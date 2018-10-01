defmodule Redis2influx.Influx do
  use Instream.Connection, otp_app: :redis2influx
end
