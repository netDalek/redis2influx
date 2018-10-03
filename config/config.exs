use Mix.Config

config :redis2influx, Redis2influx.Influx,
  database: "redis_monitor",
  host: "127.0.0.1",
  scheme: "http",
  pool: [max_overflow: 10, size: 5],
  port: 8086,
  writer: Instream.Writer.Line,
  query_timeout: 500

config :redis2influx, :interval, 1

config :redis2influx, :redises, %{}

import_config "#{Mix.env()}.exs"
