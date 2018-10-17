# Redis2influx

This application gather different numeric data from redis and send it to influxdb

## Setup

```
defp deps do
[
  # ...
  {:redis2influx, github: "netDalek/redis2influx"},
  # ...
]
end
```

## Usage

### Configure Influxdb connection

```
config :redis2influx, Redis2influx.Influx,
  scheme:    "udp",
  port:      8089
```
Read `Instream.Connection` documentation for details.
### Configure time interval in seconds  

```
config :redis2influx, :interval, 1
```

### Redis section
Redises config consists of a map with eredis connection attributes

```
config :redis2influx, redises: %{
  redis0: ['127.0.0.1', 6379, 0],
  redis1: ['127.0.0.1', 6379, 1],

  redis_group: %{
    a: ['127.0.0.1', 6379, 3],
    b: ['127.0.0.1', 6379, 4],
  }
}
```

### Configure metrics that will be send to influxdb

```
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
```

* `measurement` - influx measurement name 
* `redis` - name or list of names and groups from redis config section. See below
* `cmd` - redis command that return some numeric value. See below
* `tags` - additional influx tags

### Redis key value

Redis value in metrics section can be an atom, list of atoms and tuples.
Each item represent one redis database or a group of redis databases from redis section.
The name of redis and redis group will be added to measurement tags.

```
%{
  # ...
  redis: :redis0
  # ...
},
%{
  # ...
  redis: :redis_group
  # ...
},
%{
  # ...
  redis: {:redis_group, :a}
  # ...
},
%{
  # ...
  redis: [:redis0, :redis1, :redis_group]
  # ...
},
```

### Cmd key value

Cmd can be a list with one redis command or a map with several redis commands
```
%{
  # ...
  cmd: ["LLEN", "list1"],
  # ...
},
%{
  # ...
  cmd: %{
    list1_len: ["LLEN", "list1"],
    list2_len: ["LLEN", "list2"],
  },
  # ...
}
```

When cmd is a list with one redis command, measurement field name will be `value`.
When cmd is a map, map key become a measurement field name.

Inside redis command can be used atoms `:now` and `:now_ms`
that will be replaced with current timestamp in seconds and milliseconds accordingly

```
%{
  # ...
  cmd: %{
    l5: ["ZCOUNT", "sorted_set", 0, :now],
    l6: ["ZCOUNT", "sorted_set", 0, :now_ms],
  }
  # ...
}
```

Redis command result can be a text like this

```
# CPU
used_cpu_sys:33.46
used_cpu_user:16.57
used_cpu_sys_children:0.00
used_cpu_user_children:0.00
```

In this case every row become a separate field. Text before colon become a field name.

```
%{
  # ...
  cmd: ["INFO", "cpu"],
  # ...
}
```

## More examples

See `Redis2influx.Harvester`
