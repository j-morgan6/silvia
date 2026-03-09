defmodule Silvia.BoilerTemperature do
  use GenServer
  require Logger

  alias Silvia.Controller
  alias Silvia.Hardware.TemperatureSensor

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
    Process.send_after(self(), :check_temperature, @frequency)

    case read_sensor_temperature() do
      {:ok, temp} ->
        Controller.temperature(temp)

      {:error, reason} ->
        Logger.warning("[#{inspect(@me)}] Failed to read temperature: #{inspect(reason)}")
    end

    {:noreply, :ok}
  end

  defp read_sensor_temperature do
    TemperatureSensor.read_temperature()
  catch
    :exit, _ -> {:error, :sensor_not_available}
  end
end
