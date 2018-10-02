use Mix.Config

config :redis2influx, redises: %{
  redis0: ['127.0.0.1', 6379, 0],
  redis1: ['127.0.0.1', 6379, 1],

  redis_group: %{
    a: ['127.0.0.1', 6379, 3],
    b: ['127.0.0.1', 6379, 4],
  }
}

config :redis2influx, :metrics, [
  %{
    measurement: :metric1,
    redis: [:redis1, {:redis_group, :a}],
    cmd: ["LLEN", "list1"],
    tags: [type: :sample]
  },
  %{
    measurement: :metric4,
    redis: [:redis0, :redis1, :redis_group],
    cmd: %{
      l1: ["LLEN", "list1"],
      l2: ["LLEN", "list2"],
      l3: ["INFO", "memory"],
      l4: ["INFO", "cpu"],
      l5: ["ZCOUNT", "sorted_set", 0, :now],
      l6: ["ZCOUNT", "sorted_set", 0, :now_ms],
    },
    tags: [type: :sample]
  }
]

config :logger,
    backends: [:console]

config :logger, :file,
    path: "log/dev.log"

config :logger, :console,
    format: "\n$date $time [$level] $levelpad$metadata $message"
