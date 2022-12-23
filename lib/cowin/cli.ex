defmodule Cowin.CLI do
  @spec main([String.t()]) :: :ok | {:error, any}
  def main(args) do
    cli = cli_app()

    cli
    |> Optimus.parse!(args)
    |> case do
      {[:district_id], %Optimus.ParseResult{options: options, flags: flags}} ->
        # Handle distrit-id subcommand
        %{force_refresh: force_refresh} = flags

        case Cowin.Locations.states_districts(force_refresh) do
          {:ok, sd} ->
            %{state: state, district: district} = options
            IO.puts("#{sd |> Cowin.Locations.district_id(state, district)}")

          {:error, error} ->
            {:error, error}
        end

      {[:appointments], %Optimus.ParseResult{options: options}} ->
        # Handle appointments subcommand
        %{date: date} = options

        with(
          {:ok, sessions} <-
            case options do
              %{pincode: pincode} when not is_nil(pincode) ->
                Cowin.Appointments.by_pincode(pincode, date)

              %{district_id: district_id} when not is_nil(district_id) ->
                Cowin.Appointments.by_district(district_id, date)

              _ ->
                {:error, "One of --pincode or --district-id must be given"}
            end
        ) do
          sessions
          |> Scribe.print(
            data: [
              {"ID", :center_id},
              {"Center", :name},
              {"Vaccine", :vaccine},
              {"Age", :min_age_limit},
              {"Capacity", :available_capacity},
              {"Dose 1", :available_capacity_dose1},
              {"Dose 2", :available_capacity_dose2}
            ],
            style: Scribe.Style.Pseudo
          )
        else
          {:error, error} -> {:error, error}
        end

      _ ->
        # Show usage when no args passed
        cli |> Optimus.Help.help([], 80) |> Enum.map(&IO.puts/1)
        :ok
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
          ],
          flags: [
            force_refresh: [
              long: "force-refresh",
              multiple: false
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
