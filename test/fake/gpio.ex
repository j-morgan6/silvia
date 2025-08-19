defmodule Fake.GPIO do
  @moduledoc """
  Mock implementation of Circuits.GPIO for testing
  """
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def open(pin, direction, opts \\ []) do
    GenServer.call(__MODULE__, {:open, pin, direction, opts})
  end

  def read(ref) do
    GenServer.call(__MODULE__, {:read, ref})
  end

  def write(ref, value) do
    GenServer.call(__MODULE__, {:write, ref, value})
  end

  def close(ref) do
    GenServer.call(__MODULE__, {:close, ref})
  end

  def set_reading(value) do
    GenServer.call(__MODULE__, {:set_reading, value})
  end

  def state() do
    GenServer.call(__MODULE__, :state)
  end

  # Server callbacks

  @impl true
  def init(:ok) do
    {:ok, %{value: 1, closed: false}}
  end

  @impl true
  def handle_call({:open, pin, _direction, _opts}, _from, state) do
    {:reply, {:ok, pin}, state}
  end

  @impl true
  def handle_call({:read, _ref}, _from, state) do
    {:reply, state.value, state}
  end

  @impl true
  def handle_call({:write, _ref, value}, _from, state) do
    {:reply, :ok, %{state | value: value}}
  end

  @impl true
  def handle_call({:close, _ref}, _from, state) do
    {:reply, :ok, %{state | closed: true}}
  end

  @impl true
  def handle_call({:set_reading, value}, _from, state) do
    {:reply, :ok, %{state | value: value}}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end
end
