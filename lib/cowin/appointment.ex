defmodule Cowin.Appointments do
  @moduledoc """
  The CoWin Appointment Availability APIs
  """

  use Cowin

  @pincode_endpoint "/v2/appointment/sessions/public/findByPin"

  @doc """
    Check if any slots are currently available for pincode, and return a list of locations
  sorted by most slots available
  """
  @spec check_pincode(String.t(), Date.t()) ::
          {:ok, list[%{optional(any) => any}]} | {:error, any}
  def check_pincode(pincode, date \\ Timex.today("Asia/Kolkata")) do
    get(@pincode_endpoint,
      query: [
        pincode: pincode,
        date: Timex.format!(date, "0{D}-0{M}-{YYYY}")
      ]
    )
    |> case do
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
end
