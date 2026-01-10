defmodule Silvia.BoilerTemperature do
  use GenServer
  require Logger

  alias Silvia.Controller

  @me __MODULE__
  @frequency 1_000

  def start_link(_) do
    GenServer.start_link(__MODULE__, :noargs, name: @me)
  end

  def init(:noargs) do
    Logger.info("[#{inspect(@me)}] starting BoilerTemperature GenServer")
    Process.send_after(self(), :check_temperature, @frequency)
    {:ok, :ok}
  end

  def handle_info(:check_temperature, :ok) do
    boiler_temperature = boiler_temperature()
    Process.send_after(self(), :check_temperature, @frequency)
    Controller.temperature(boiler_temperature)
    {:noreply, :ok}
  end

  defp boiler_temperature() do
    case Silvia.Hardware.HeatSensor.get_temperature() do
      {:ok, temp} ->
        Logger.info("[#{inspect(@me)}] ✓ TSIC306 reading: #{Float.round(temp, 2)}°C")
        temp
      {:error, reason} ->
        Logger.error("[#{inspect(@me)}] ✗ TSIC306 FAILED: #{inspect(reason)} - Check GPIO 4 wiring")
        Enum.random(92..145)
    end
  end
end