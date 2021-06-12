defmodule Cowin.CLI do
  @spec main([String.t()]) :: :ok | {:err, any}
  def main(args) do
    cli_app()
    |> Optimus.parse!(args)
    |> case do
      {[:district_id], %Optimus.ParseResult{options: options}} ->
        case Cowin.Locations.states_districts() do
          {:ok, sd} ->
            %{state: state, district: district} = options
            IO.puts("#{sd |> Cowin.Locations.district_id(state, district)}")

          {:err, error} ->
            {:err, error}
        end

      {[:appointments], %Optimus.ParseResult{options: options}} ->
        %{date: date} = options
        with(
          {:ok, sessions} <-
            case options do
              %{pincode: pincode} when not is_nil(pincode)->
                Cowin.Appointments.by_pincode(pincode, date)

              %{district_id: district_id} when not is_nil(district_id)->
                Cowin.Appointments.by_district(district_id, date)

              _ ->
                {:error, "One of --pincode or --district-id must be given"}
            end
        ) do
              IO.inspect(sessions)
              :ok
        else
          {:err, error} -> {:err, error}
        end
    end
  end

  @spec cli_app() :: Optimus.t()
  defp cli_app() do
    Optimus.new!(
      name: "cowin-ex",
      subcommands: [
        district_id: [
          name: "district-id",
          options: [
            state: [
              long: "state",
              required: true,
              parser: :string
            ],
            district: [
              long: "district",
              required: true,
              parser: :string
            ]
          ]
        ],
        appointments: [
          name: "appointments",
          options: [
            pincode: [
              long: "pincode",
              parser: :string
            ],
            district_id: [
              long: "district-id",
              parser: :integer
            ],
            date: [
              long: "date",
              default: Timex.today("Asia/Kolkata"),
              parser: fn s ->
                case Date.from_iso8601(s) do
                  {:error, _} -> {:error, "invalid date"}
                  {:ok, _} = ok -> ok
                end
              end,
              required: false
            ]
          ]
        ]
      ]
    )
  end
end
