defmodule Fake.GPIO do
  @moduledoc """
  Mock implementation of Circuits.GPIO for testing

  Requires the tests to set its' pid to receive messages
  """

  def open(pin, direction) do
    send(test_module(), {:gpio_open, pin, direction})
    {:ok, pin}
  end

  def write(pin, value) do
    send(test_module(), {:gpio_write, pin, value})
    :ok
  end

  def close(pin) do
    send(test_module(), {:gpio_close, pin})
    :ok
  end

  defp test_module() do
    Application.get_env(:silvia, :gpio_test_pid, self())
  end
end
