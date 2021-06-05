defmodule Cowin do
  @moduledoc """
    CoWIN APIs in Elixir
  """

  defmacro __using__(_) do
    quote do
      use Tesla, only: [:get]
      adapter(Tesla.Adapter.Hackney)
      plug(Tesla.Middleware.BaseUrl, "https://cdn-api.co-vin.in/api")
      plug(Tesla.Middleware.Headers, [{"user-agent", "cowin-elixir"}, {"Accept-Language", "en_US"}])
      plug(Tesla.Middleware.JSON)
      plug(Tesla.Middleware.Logger)
    end
  end
end