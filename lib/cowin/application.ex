defmodule Cowin.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  import Bakeware.Script, only: [get_argc!: 0, get_args: 1, result_to_halt: 1]

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: Cowin.Finch},
      %{id: Task, restart: :temporary, start: {Task, :start_link, [&__MODULE__._main/0]}}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ImgurdlApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc false
  def _main() do
    get_argc!()
    |> get_args()
    |> Cowin.CLI.main()
    |> result_to_halt()
    |> :erlang.halt()
  catch
    error, reason ->
      IO.warn(
        "Caught exception in #{__MODULE__}.main/1: #{inspect(error)} => #{inspect(reason, pretty: true)}",
        __STACKTRACE__
      )

      :erlang.halt(1)
  end
end
