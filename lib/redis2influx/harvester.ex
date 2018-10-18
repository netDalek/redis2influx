defmodule Redis2influx.Harvester do
  @moduledoc """
    Module for internal use
  """

  require Logger

  defstruct field: :value,
            tags: [],
            result: nil,
            measurement: nil,
            cmd: nil,
            result: nil,
            redis: nil,
            redis_args: nil

  @redis_client Application.get_env(:redis2influx, :redis_client, Redis2influx.Eredis)

  @doc """
  ## Examples
      iex> check([%{measurement: "m", cmd: [], redis: :a}], %{a: []}, 0)
      [%{tags: %{redis: :a}, fields: %{value: 1}, measurement: "m", timestamp: 0}]

      #redis with connection error
      iex> check([%{measurement: "m", cmd: [], redis: :a}], %{a: [:error_args]}, 0)
      []

      #multiply commands
      iex> check([%{measurement: "m", cmd: %{x: [], y: []}, redis: :a}], %{a: []}, 0)
      [
        %{tags: %{redis: :a}, fields: %{x: 1}, measurement: "m", timestamp: 0},
        %{tags: %{redis: :a}, fields: %{y: 1}, measurement: "m", timestamp: 0}
      ]

      #:now and :now_ms substitution
      iex> check([%{measurement: "m", cmd: ["ZCOUNT", "key", 0, :now], redis: :a}], %{a: []}, 1000)
      [%{tags: %{redis: :a}, fields: %{value: 10}, measurement: "m", timestamp: 1_000_000_000}]

      iex> check([%{measurement: "m", cmd: ["ZCOUNT", "key", 0, :now_ms], redis: :a}], %{a: []}, 1000)
      [%{tags: %{redis: :a}, fields: %{value: 20}, measurement: "m", timestamp: 1_000_000_000}]

      #using one redis connection from redis group
      iex> check([%{measurement: "m", cmd: [], redis: {:a, :b}}], %{a: %{b: []}}, 0)
      [%{tags: %{redis_group: :a, redis: :b}, fields: %{value: 1}, measurement: "m", timestamp: 0}]

      #using whole redis group
      iex> check([%{measurement: "m", cmd: [], redis: :a}], %{a: %{b: [], c: []}}, 0)
      [
        %{fields: %{value: 1}, measurement: "m", tags: %{redis: :b, redis_group: :a}, timestamp: 0},
        %{fields: %{value: 1}, measurement: "m", tags: %{redis: :c, redis_group: :a}, timestamp: 0}
      ]

      #using several redis databases
      iex> check([%{measurement: "m", cmd: [], redis: [:a, :b]}], %{a: [], b: []}, 0)
      [
        %{fields: %{value: 1}, measurement: "m", tags: %{redis: :a}, timestamp: 0},
        %{fields: %{value: 1}, measurement: "m", tags: %{redis: :b}, timestamp: 0}
      ]

      #add extra tags
      iex> check([%{measurement: "m", cmd: [], redis: :a, tags: [a: :b]}], %{a: []}, 0)
      [%{tags: %{redis: :a, a: :b}, fields: %{value: 1}, measurement: "m", timestamp: 0}]

      #gather memory and cpu info
      iex> check([%{measurement: :name, redis: :r1, cmd: [:info, :cpu]}], %{r1: []}, 0)
      [
        %{measurement: :name, fields: %{"used_cpu_sys" => 33.46},         tags: %{redis: :r1}, timestamp: 0},
        %{measurement: :name, fields: %{"used_cpu_user" => 16.57},        tags: %{redis: :r1}, timestamp: 0},
        %{measurement: :name, fields: %{"used_cpu_sys_children" => 0.0},  tags: %{redis: :r1}, timestamp: 0},
        %{measurement: :name, fields: %{"used_cpu_user_children" => 0.0}, tags: %{redis: :r1}, timestamp: 0}
      ]
  """
  def check(
        metrics \\ Application.get_env(:redis2influx, :metrics, []),
        redises \\ Application.get_env(:redis2influx, :redises, %{}),
        ms_timestamp \\ :os.system_time(:milli_seconds)
      ) do
    interval = Redis2influx.interval()

    nanosecond_timestamp = interval * div(ms_timestamp, interval * 1000) * 1_000_000_000

    metrics
    |> Enum.map(&struct(__MODULE__, &1))
    |> Enum.flat_map(&flatten/1)
    |> Enum.flat_map(&resolve_redises(&1, redises))
    |> Enum.map(&substitute(&1, ms_timestamp))
    |> Enum.map(&measure/1)
    |> Enum.filter(fn m -> m.result != nil end)
    |> Enum.flat_map(&parse_result/1)
    |> Enum.map(&build_influx_data/1)
    |> Enum.map(&Map.put(&1, :timestamp, nanosecond_timestamp))
  end

  defp resolve_redises(%{redis: {redis, subname}} = metric, redises) do
    %{^redis => %{^subname => args}} = redises

    [
      %{metric | redis_args: args}
      |> add_tags(redis_group: redis, redis: subname)
    ]
  end

  defp resolve_redises(%{redis: redis} = metric, redises) do
    case redises |> Map.fetch!(redis) do
      map when is_map(map) ->
        map
        |> Enum.map(fn {subname, args} ->
          %{metric | redis_args: args}
          |> add_tags(redis: subname, redis_group: redis)
        end)

      args ->
        [
          %{metric | redis_args: args}
          |> add_tags(redis: redis)
        ]
    end
  end

  defp flatten(%{cmd: cmds} = metric) when is_map(cmds) do
    cmds
    |> Enum.flat_map(fn {name, cmd} ->
      %{metric | cmd: cmd, field: name}
      |> flatten
    end)
  end

  defp flatten(%{redis: redises} = metric) when is_list(redises) do
    redises
    |> Enum.flat_map(fn redis ->
      %{metric | redis: redis}
      |> flatten
    end)
  end

  defp flatten(metric) do
    [metric]
  end

  defp substitute(%{cmd: cmd} = metric, ms_timestamp) do
    newcmd =
      Enum.map(cmd, fn
        :now ->
          div(ms_timestamp, 1000)

        :now_ms ->
          ms_timestamp

        smth ->
          smth
      end)

    %{metric | cmd: newcmd}
  end

  defp measure(%{cmd: cmd} = metric) do
    case @redis_client.q(metric.redis_args, cmd) do
      {:error, reason} ->
        Logger.info(
          "error #{inspect(reason)} while send #{inspect(cmd)} to #{inspect(metric.redis_args)}"
        )

        metric

      {:ok, value} ->
        %{metric | result: value}
    end
  end

  defp parse_result(%{result: value} = metric) do
    case value |> String.split() |> Enum.map(&String.split(&1, ":")) do
      [[value]] ->
        {int_value, _} = Integer.parse(value)
        [%{metric | result: int_value}]

      splitted ->
        parsed = for [name, value] <- splitted, do: {name, Float.parse(value)}
        metrics = for {name, {float_value, _}} <- parsed, do: {name, float_value}

        Enum.map(metrics, fn {name, float_value} ->
          %{metric | result: float_value, field: name}
        end)
    end
  end

  defp build_influx_data(%{result: value, field: field_name, measurement: measurement, tags: tags}) do
    %{
      measurement: measurement,
      fields: %{field_name => value},
      tags: :maps.from_list(tags)
    }
  end

  defp add_tags(%{tags: old_tags} = metric, tags) do
    %{metric | tags: old_tags ++ tags}
  end
end
