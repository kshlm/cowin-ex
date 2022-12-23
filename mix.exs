defmodule Cowin.MixProject do
  use Mix.Project

  def project do
    [
      app: :cowin,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: release()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Cowin.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bakeware, "~> 0.2"},
      {:castore, "~> 0.1"},
      {:finch, "~> 0.7"},
      {:flow, "~> 1.1"},
      {:jason, "~> 1.2"},
      {:optimus, "~>0.2"},
      {:scribe, "~>0.10"},
      {:tesla, "~>1.5"},
      {:timex, "~> 3.7"}
    ]
  end

  defp release do
    [
      cowin_ex: [
        name: "cowin-ex",
        steps: [:assemble, &Bakeware.assemble/1]
      ]
    ]
  end
end
