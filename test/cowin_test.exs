defmodule CowinTest do
  use ExUnit.Case
  doctest Cowin

  test "greets the world" do
    assert Cowin.hello() == :world
  end
end
