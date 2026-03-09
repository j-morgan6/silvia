defmodule Fake.SPI do
  @moduledoc """
  Mock implementation of Circuits.SPI for testing MAX31865 communication.
  Simulates SPI register reads/writes with configurable responses.
  """
  use GenServer
  import Bitwise

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def open(_bus, _opts \\ []) do
    {:ok, :fake_spi_ref}
  end

  def transfer(_ref, data) do
    GenServer.call(__MODULE__, {:transfer, data})
  end

  def close(_ref), do: :ok

  # Test helpers

  def set_rtd_value(rtd_raw) do
    # RTD register format: 15-bit value left-shifted by 1 (bit 0 = fault flag)
    value = rtd_raw <<< 1
    msb = value >>> 8 &&& 0xFF
    lsb = value &&& 0xFF
    GenServer.call(__MODULE__, {:set_registers, %{0x01 => msb, 0x02 => lsb}})
  end

  def set_fault(fault_byte) do
    GenServer.call(__MODULE__, {:set_registers, %{0x07 => fault_byte}})
  end

  def set_rtd_fault_bit do
    GenServer.call(__MODULE__, :set_rtd_fault_bit)
  end

  def get_writes do
    GenServer.call(__MODULE__, :get_writes)
  end

  # Server callbacks

  @impl true
  def init(:ok) do
    {:ok,
     %{
       registers: %{
         0x00 => 0x00,
         0x01 => 0x00,
         0x02 => 0x00,
         0x07 => 0x00
       },
       writes: []
     }}
  end

  @impl true
  def handle_call({:transfer, <<address, value>>}, _from, state) do
    if (address &&& 0x80) != 0 do
      # Write operation: address has bit 7 set
      reg = address &&& 0x7F
      new_registers = Map.put(state.registers, reg, value)
      new_writes = [{reg, value} | state.writes]
      {:reply, {:ok, <<0x00, 0x00>>}, %{state | registers: new_registers, writes: new_writes}}
    else
      # Read operation
      reg_value = Map.get(state.registers, address, 0x00)
      {:reply, {:ok, <<0x00, reg_value>>}, state}
    end
  end

  @impl true
  def handle_call({:set_registers, regs}, _from, state) do
    new_registers = Map.merge(state.registers, regs)
    {:reply, :ok, %{state | registers: new_registers}}
  end

  @impl true
  def handle_call(:set_rtd_fault_bit, _from, state) do
    lsb = Map.get(state.registers, 0x02, 0x00)
    new_registers = Map.put(state.registers, 0x02, lsb ||| 0x01)
    {:reply, :ok, %{state | registers: new_registers}}
  end

  @impl true
  def handle_call(:get_writes, _from, state) do
    {:reply, Enum.reverse(state.writes), state}
  end
end
