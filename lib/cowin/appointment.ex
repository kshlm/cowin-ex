defmodule Cowin.Appointments do
  @moduledoc """
  The CoWin Appointment Availability APIs
  """

  use Cowin

  @pincode_endpoint "/v2/appointment/sessions/public/findByPin"
  @district_endpoint "/v2/appointment/sessions/public/findByDistrict"
  @cal_pincode_endpoint "/v2/appointment/sessions/public/calendarByPin"
  @cal_district_endpoint "/v2/appointment/sessions/public/calendarByDistrict"

  @doc """
    Check if any slots on given date are currently available for pincode, and
  return a list of locations sorted by most slots available
  """
  @spec by_pincode(String.t(), Date.t()) ::
          {:ok, list[%{optional(any) => any}]} | {:error, any}
  def by_pincode(pincode, date \\ Timex.today("Asia/Kolkata")) do
    get(@pincode_endpoint,
      query: [
        pincode: pincode,
        date: Timex.format!(date, "0{D}-0{M}-{YYYY}")
      ]
    )
    |> handle_day_resp
  end

  @doc """
    Check if any slots on given date are currently available for district, and
  return a list of locations sorted by most slots available.
    Get district_id using of Cowin.Locations.states_districts/0 and Cowin.Locations.district_id/3
  """
  @spec by_district(number, Date.t()) ::
          {:ok, list[%{optional(any) => any}]} | {:error, any}
  def by_district(district_id, date \\ Timex.today("Asia/Kolkata")) do
    get(@district_endpoint,
      query: [
        district_id: district_id,
        date: Timex.format!(date, "{0D}-{0M}-{YYYY}")
      ]
    )
    |> handle_day_resp
  end

  @spec handle_day_resp(Tesla.Env) ::
          {:ok, list[%{optional(any) => any}]} | {:error, any}
  defp handle_day_resp(response) do
    case response do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {
          :ok,
          body[:sessions]
          |> Enum.filter(fn %{available_capacity: capacity} -> capacity > 0 end)
          |> Enum.sort_by(fn %{available_capacity: capacity} -> capacity end, :desc)
        }

      _ ->
        {:error, "Something failed"}
    end
  end

  @doc """
    Check if any slots in the week starting on given date are currently
  available for pincode, and return a list of locations
  """
  @spec calendar_by_pincode(String.t(), Date.t()) ::
          {:ok, list[%{optional(any) => any}]} | {:error, any}
  def calendar_by_pincode(pincode, date \\ Timex.today("Asia/Kolkata")) do
    get(@cal_pincode_endpoint,
      query: [
        pincode: pincode,
        date: Timex.format!(date, "0{D}-0{M}-{YYYY}")
      ]
    )
    |> handle_calendar_resp
  end

  @doc """
    Check if any slots in the week starting on given date are currently
  available for district, and return a list of locations
    Get district_id using of Cowin.Locations.states_districts/0 and Cowin.Locations.district_id/3
  """
  @spec calendar_by_district(number, Date.t()) ::
          {:ok, list[%{optional(any) => any}]} | {:error, any}
  def calendar_by_district(district_id, date \\ Timex.today("Asia/Kolkata")) do
    get(@cal_district_endpoint,
      query: [
        district_id: district_id,
        date: Timex.format!(date, "0{D}-0{M}-{YYYY}")
      ]
    )
    |> handle_calendar_resp
  end

  @spec handle_calendar_resp(Tesla.Env) ::
          {:ok, list[%{optional(any) => any}]} | {:error, any}
  defp handle_calendar_resp(response) do
    case response do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {
          :ok,
          body[:centers]
          |> Enum.map(fn center ->
            %{
              center
              | sessions:
                  center.sessions
                  |> Enum.filter(fn %{available_capacity: capacity} -> capacity > 0 end)
            }
          end)
          |> Enum.filter(fn %{sessions: sessions} -> length(sessions) > 0 end)
          |> Enum.sort_by(
            fn %{sessions: sessions} ->
              sessions |> Enum.reduce(0, fn s, a -> a + s.available_capacity end)
            end,
            :desc
          )
        }

      _ ->
        {:error, "Something failed"}
    end
  end
end
