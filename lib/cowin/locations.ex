defmodule Cowin.Locations do
  @moduledoc """
  The CoWIN Locations metadata APIs
  """
  use Cowin
  require Logger

  @cache_file "cowin-states-districts.json"

  @states_endpoint "/v2/admin/location/states"
  @districts_endpoint "/v2/admin/location/districts/"

  @type state :: %{
          state_id: number,
          state_name: String.t(),
          districts: %{optional(String.t()) => district}
        }
  @type district :: %{
          district_id: number,
          district_name: String.t(),
          district_name_l: String.t(),
          state_id: number
        }
  @type sd_map :: %{optional(String.t()) => state}

  @doc """
    Return a map of states and districts. Returns from the local copy if
  available, if not fetches from the CoWIN API.
  """
  @spec states_districts() :: {:ok, sd_map} | {:error, any}
  def states_districts() do
    case load_cache() do
      {:ok, sd_map} ->
        {:ok, sd_map}

      {:error, msg} ->
        Logger.error(msg)
        fetch_and_cache()
    end
  end

  @doc """
  Returns the district ID for the requested district
  """
  @spec district_id(sd_map, String.t(), String.t()) :: number
  def district_id(sd_map, state, district) do
    sd_map[state][:districts][district][:id]
  end

  @doc """
  Fetches the list of states from the CoWIN API
  """
  @spec get_states() ::
          {:ok,
           %{
             ttl: number,
             fetch_time: DateTime.t(),
             states: list(state)
           }}
          | {:error, any}
  def get_states() do
    fetch_time = Timex.now()

    get(@states_endpoint)
    |> case do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, Map.put(body, :fetch_time, fetch_time)}

      _ ->
        {:error, "An error occurred fetching states from the CoWIN API"}
    end
  end

  @doc """
  Fetches the list of districts for the given state from the CoWIN API
  """
  @spec get_districts(number) ::
          {:ok,
           %{
             ttl: number,
             fetch_time: DateTime.t(),
             districts: list(district)
           }}
          | {:error, any}
  def get_districts(state_id) do
    fetch_time = Timex.now()

    get(@districts_endpoint <> "#{state_id}")
    |> case do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok,
         %{
           body
           | districts: body[:districts] |> Enum.map(fn d -> Map.put(d, :state_id, state_id) end)
         }
         |> Map.put(:fetch_time, fetch_time)}

      _ ->
        {:error, "An error occurred fetching districts from the CoWIN API"}
    end
  end

  @spec build_sd_map(list(state), list(district)) :: sd_map
  defp build_sd_map(states, districts) do
    states
    |> Enum.into(
      %{},
      fn state ->
        {state[:state_name],
         Map.put(
           state,
           :districts,
           districts
           |> Enum.filter(fn %{state_id: d_sid} -> d_sid == state[:state_id] end)
           |> Enum.into(%{}, fn district -> {district[:district_name], district} end)
         )}
      end
    )
  end

  @spec fetch_and_cache() :: {:ok, sd_map()} | {:error, any()}
  defp fetch_and_cache() do
    fetch_time = Timex.now()

    case get_states() do
      {:ok, states} ->
        districts = states[:states] |> Enum.map(fn %{state_id: id} -> get_districts(id) end)

        min_ttl =
          [states[:ttl] | districts |> Enum.map(fn {:ok, %{ttl: ttl}} -> ttl end)] |> Enum.min()

        districts_flattened =
          districts
          |> Enum.map(fn {:ok, %{districts: districts}} -> districts end)
          |> Enum.concat()

        data = %{
          expires_at: fetch_time |> Timex.shift(hours: min_ttl) |> DateTime.to_iso8601(),
          states: states[:states],
          districts: districts_flattened
        }

        Logger.info("Fetched fresh data from API")

        # Save to local cache
        with {:ok, json_data} <- Jason.encode_to_iodata(data, pretty: true),
             :ok <- File.write(@cache_file, json_data) do
          Logger.info("Saved states/districts to cache")
        else
          _ ->
            Logger.warn("Saving states/districts to cache failed")
        end

        # Form and return the map
        {:ok, build_sd_map(states[:states], districts_flattened)}

      {:error, err} ->
        {:error, err}
    end
  end

  @spec load_cache() :: {:ok, sd_map} | {:error, any}
  defp load_cache do
    if File.exists?(@cache_file) do
      with {:ok, json_data} <- File.read(@cache_file),
           {:ok, %{expires_at: expires_at, states: states, districts: districts}} <-
             Jason.decode(json_data, keys: :atoms),
           {:ok, expiry_time, 0} <- DateTime.from_iso8601(expires_at) do
        if Timex.before?(Timex.now(), expiry_time) do
          Logger.info("Loaded data from cache")
          {:ok, build_sd_map(states, districts)}
        else
          {:error, "Cache expired"}
        end
      else
        error ->
          {:error, {"Unknown error loading cache", error}}
      end
    else
      {:error, "Cache not present"}
    end
  end
end
