defmodule Silvia.Dashboard do
  use GenServer
  require Logger

  @me __MODULE__

  def start_link(_) do
    GenServer.start_link(__MODULE__, :noargs, name: @me)
  end

  def temperature(temp) do
    GenServer.cast(@me, {:temperature, temp})
  end

  def brew_temperature(temp) do
    GenServer.cast(@me, {:brew_temperature, temp})
  end

  def steam_temperature(temp) do
    GenServer.cast(@me, {:steam_temperature, temp})
  end

  def wifi_status(status) do
    GenServer.cast(@me, {:wifi_status, status})
  end

  def dashboard_info() do
    GenServer.call(@me, :dashboard_info)
  end
  
  def init(:noargs) do
    Logger.info("[#{inspect(@me)}] starting Controller GenServer")
    {:ok,
      %{
        temperature: Enum.random(94..96),
        brew_temperature: Enum.random(92..98),
        steam_temperature: Enum.random(135..145),
        wifi_status: :starting
      }
    }
  end

  def handle_cast({:temperature, temp}, state) do
    Logger.info("[#{inspect(@me)}] temperature: #{inspect(temp)}")
    {:noreply, %{state | temperature: temp}}
  end

  def handle_cast({:brew_temperature, temp}, state) do
    Logger.info("[#{inspect(@me)}] brew temperature: #{inspect(temp)}")
    {:noreply, %{state | brew_temperature: temp}}
  end

  def handle_cast({:steam_temperature, temp}, state) do
    Logger.info("[#{inspect(@me)}] steam temperature: #{inspect(temp)}")
    {:noreply, %{state | steam_temperature: temp}}
  end

  def handle_cast({:wifi_status, {conn, ssid} = _wifi_status}, state) do
    Logger.info("[#{inspect(@me)}] wifi status: connection #{conn}, ssid #{ssid}")
    {:noreply, %{state | wifi_status: conn}}
  end

  def handle_call(:dashboard_info, _from, state) do
    Logger.info("[#{inspect(@me)}] dashboard info request")
    {:reply, state, state}
  end

end