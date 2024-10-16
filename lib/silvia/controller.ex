defmodule Silvia.Controller do
  use GenServer
  require Logger

  @me __MODULE__

  def start_link(_) do
    GenServer.start_link(__MODULE__, :noargs, name: @me)
  end

  def info(text) do
    GenServer.cast(@me, {:info, text})
  end

  def alert(text) do
    GenServer.cast(@me, {:alert, text})
  end

  def temperature(temp) do
    GenServer.cast(@me, {:temperature, temp})
  end

  def wifi(wifi_status) do
    GenServer.cast(@me, {:wifi, wifi_status})
  end

  def init(:noargs) do
    Logger.info("[#{inspect(@me)}] starting Controller GenServer")
    {:ok, %{temperature: 0.0, wifi_status: {:starting, ""}}}
  end

  def handle_cast({:info, text}, state) do
    Logger.info("[#{inspect(@me)}] info: #{text}")
    {:noreply, state}
  end

  def handle_cast({:alert, text}, state) do
    Logger.info("[#{inspect(@me)}] alert: #{text}")
    {:noreply, state}
  end

  def handle_cast({:temperature, temp}, %{temperature: _prev_temp} = state) do
    Logger.info("[#{inspect(@me)}] temperature: #{inspect(temp)}")
    {:noreply, %{state | temperature: temp}}
  end

  def handle_cast({:wifi, wifi_status}, state) do
    Logger.info("[#{inspect(@me)}] wifi: #{inspect(wifi_status)}")
    {:noreply, %{state | wifi_status: wifi_status}}
  end

end