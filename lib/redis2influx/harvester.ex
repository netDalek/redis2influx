defmodule Redis2influx.Harvester do
  require Logger

  alias Redis2influx.Eredis

  @defaults %{value: :value, tags: []}
  @metrics Application.get_env(:redis2influx, :metrics, [])

  def check(metrics \\ @metrics) do
    redises = Application.fetch_env!(:redis2influx, :redises)

    points = metrics
    |> Enum.map(&Map.merge(@defaults, &1))
    |> flatten
    |> Enum.flat_map(&resolve_redises(&1, redises))
    |> Enum.map(&substitute/1)
    |> Enum.map(&measure/1)
    |> Enum.filter(fn(m) -> Map.has_key?(m, :result) end)
    |> Enum.map(&build_influx_data/1)

    Logger.debug("writing points #{inspect points}")

    %{points: points}
    |> Redis2influx.Influx.write
  end

  @doc """
  ## Examples

      iex> Redis2influx.Harvester.resolve_redises(%{redis: :a}, %{a: 123})
      [%{redis_args: 123, tags: [redis: :a]}]

      iex> Redis2influx.Harvester.resolve_redises(%{redis: {:a, :b}}, %{a: %{b: 123}})
      [%{redis_args: 123, tags: [redis_group: :a, redis: :b]}]

      iex> Redis2influx.Harvester.resolve_redises(%{redis: :a}, %{a: %{b: 123}})
      [%{redis_args: 123, tags: [redis: :b, redis_group: :a]}]
  """
  def resolve_redises(%{redis: {redis, subname}} = metric, redises) do
    args = redises
           |> Map.fetch!(redis)
           |> Map.fetch!(subname)
    [
      metric
      |> Map.delete(:redis)
      |> Map.put(:redis_args, args)
      |> add_tags([redis_group: redis, redis: subname])
    ]
  end
  def resolve_redises(%{redis: redis} = metric, redises) do
    case redises |> Map.fetch!(redis) do
      map when is_map(map) ->
        map
        |> Map.to_list
        |> Enum.map(fn({subname, args}) ->
          metric
          |> Map.delete(:redis)
          |> Map.put(:redis_args, args)
          |> add_tags([redis: subname, redis_group: redis])
        end)
      args ->
        [
          metric
          |> Map.delete(:redis)
          |> Map.put(:redis_args, args)
          |> add_tags([redis: redis])
        ]
    end
  end

  @doc """
  ## Examples

      iex> Redis2influx.Harvester.flatten(%{redis: [:a, :b]})
      [
        %{redis: :a},
        %{redis: :b}
      ]
  """
  def flatten(metrics) when is_list(metrics) do
    metrics |> Enum.flat_map(&flatten/1)
  end
  def flatten(%{cmd: cmds} = metric) when is_map(cmds) do
    cmds |> Enum.flat_map(fn({name, cmd}) ->
      %{metric | cmd: cmd, value: name}
      |> flatten
    end)
  end
  def flatten(%{redis: redises} = metric) when is_list(redises) do
    redises |> Enum.flat_map(fn(redis) ->
      %{metric | redis: redis}
      |> flatten
    end)
  end
  def flatten(%{section: sections} = metric) when is_list(sections) do
    sections |> Enum.flat_map(fn(section) ->
      %{metric | section: section}
      |> add_tags([section: section])
      |> flatten
    end)
  end
  def flatten(metric) do
    [metric]
  end

  def substitute(%{cmd: cmd} = metric) do
    newcmd = cmd |> Enum.map(fn
      :now -> 
        :os.system_time(:seconds)
      :now_ms -> 
        :erlang.system_time(:milli_seconds)
      smth ->
        smth
    end)
    %{metric | cmd: newcmd}
  end

  def measure(%{cmd: cmd} = metric) do
    case Eredis.q(metric.redis_args, cmd) do
      {:error, reason} ->
        Logger.info("error #{inspect reason} while send #{inspect cmd} to #{inspect metric.redis_args}")
        metric
      {:ok, value} ->
        metric |> Map.put(:result, value)
    end
  end

  @doc """
  ## Examples

      iex> Redis2influx.Harvester.build_influx_data(%{measurement: :name, redis_args: :r1, cmd: :c1, tags: [], result: "123"})
      %{fields: %{value: 123}, measurement: :name, tags: []}
      iex> Redis2influx.Harvester.build_influx_data(%{measurement: :name, redis_args: :r1, cmd: :c1, tags: [a: :b], result: "123"})
      %{fields: %{value: 123}, measurement: :name, tags: [a: :b]}

      iex> Redis2influx.Harvester.build_influx_data(%{measurement: :name, redis_args: :r1, section: :c1, tags: [], result: "a:123"})
      %{fields: %{"a" => 123.0}, measurement: :name, tags: []}

      iex> Redis2influx.Harvester.build_influx_data(%{measurement: :name, redis_args: :r1, section: :c1, tags: [], result: "#CPU\\r\\nb:smth\\r\\na:123"})
      %{fields: %{"a" => 123.0}, measurement: :name, tags: []}

  """
  def build_influx_data(metric) do
    value = metric.result
    value_name = metric |> Map.get(:value, :value)

    case value |> String.split |> Enum.map(&(String.split(&1, ":"))) do
      [[value]] ->
        {int_value, _} = Integer.parse(value)
        %{
          measurement: metric.measurement,
          fields:      %{value_name => int_value},
          tags:        metric.tags
        }
      splitted ->
        parsed = for [name, value] <- splitted do
          {name, Float.parse(value)}
        end
        metrics = for {name, {value, _}} <- parsed do
          {name, value}
        end

        %{
          measurement: metric.measurement,
          fields:      :maps.from_list(metrics),
          tags:        metric.tags
        }
    end
  end

  @doc """
  ## Examples

      iex> Redis2influx.Harvester.add_tags(%{tags: [a: 1]}, [b: 1])
      %{tags: [a: 1, b: 1]}
  """
  def add_tags(metric, tags) do
    old_tags = Map.get(metric, :tags, [])
    metric
    |> Map.put(:tags, old_tags ++ tags)
  end
end
