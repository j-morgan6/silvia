defmodule Silvia.Hardware.TemperatureSensorTest do
  use ExUnit.Case, async: false

  alias Silvia.Hardware.TemperatureSensor

  setup do
    start_supervised!(Fake.SPI)

    sensor_name = :"sensor_#{:erlang.unique_integer([:positive])}"
    start_supervised!({TemperatureSensor, [name: sensor_name]})

    %{sensor: sensor_name}
  end

  describe "init/1" do
    test "writes config register on startup" do
      writes = Fake.SPI.get_writes()
      # Should have written config register (0x00) with bias on (0b10010000 = 0x90)
      assert {0x00, 0x90} in writes
    end
  end

  describe "read_temperature/0" do
    test "returns temperature for known RTD value at 0°C" do
      # At 0°C, resistance = 100.0 ohms
      # rtd_raw = R / R_ref * 32768 = 100.0 / 430.0 * 32768 = 7622
      Fake.SPI.set_rtd_value(7622)
      assert {:ok, temp} = TemperatureSensor.read_temperature()
      assert_in_delta temp, 0.0, 0.5
    end

    test "returns temperature for known RTD value at 100°C" do
      # At 100°C, resistance = 138.51 ohms
      # rtd_raw = 138.51 / 430.0 * 32768 = 10553
      Fake.SPI.set_rtd_value(10553)
      assert {:ok, temp} = TemperatureSensor.read_temperature()
      assert_in_delta temp, 100.0, 0.5
    end

    test "returns temperature at 25°C (room temp)" do
      # At 25°C, resistance = 109.73 ohms
      # rtd_raw = 109.73 / 430.0 * 32768 = 8361
      Fake.SPI.set_rtd_value(8361)
      assert {:ok, temp} = TemperatureSensor.read_temperature()
      assert_in_delta temp, 25.0, 0.5
    end

    test "returns temperature at 93°C (brew target)" do
      # At 93°C, resistance = 135.88 ohms
      # rtd_raw = 135.88 / 430.0 * 32768 = 10352
      Fake.SPI.set_rtd_value(10352)
      assert {:ok, temp} = TemperatureSensor.read_temperature()
      assert_in_delta temp, 93.0, 0.5
    end

    test "returns error when RTD fault bit is set" do
      Fake.SPI.set_rtd_value(8000)
      Fake.SPI.set_rtd_fault_bit()
      assert {:error, :fault_detected} = TemperatureSensor.read_temperature()
    end
  end

  describe "fault detection" do
    test "returns error for open RTD circuit" do
      Fake.SPI.set_rtd_value(8000)
      # 0x08 = RTD force- low/open fault
      Fake.SPI.set_fault(0x08)
      assert {:error, {:fault, :rtd_force_low_open}} = TemperatureSensor.read_temperature()
    end

    test "returns error for overvoltage/undervoltage" do
      Fake.SPI.set_rtd_value(8000)
      Fake.SPI.set_fault(0x04)
      assert {:error, {:fault, :overvoltage_undervoltage}} = TemperatureSensor.read_temperature()
    end

    test "returns multiple faults when multiple flags set" do
      Fake.SPI.set_rtd_value(8000)
      # 0x88 = RTD high threshold + RTD force low/open
      Fake.SPI.set_fault(0x88)
      assert {:error, {:fault, faults}} = TemperatureSensor.read_temperature()
      assert is_list(faults)
      assert :rtd_high_threshold in faults
      assert :rtd_force_low_open in faults
    end
  end

  describe "rtd_to_temperature/1" do
    test "converts 0°C correctly" do
      # 100.0 / 430.0 * 32768 = 7622
      temp = TemperatureSensor.rtd_to_temperature(7622)
      assert_in_delta temp, 0.0, 0.5
    end

    test "converts 100°C correctly" do
      # 138.51 / 430.0 * 32768 = 10553
      temp = TemperatureSensor.rtd_to_temperature(10553)
      assert_in_delta temp, 100.0, 0.5
    end

    test "converts 150°C correctly" do
      # 157.33 / 430.0 * 32768 = 11987
      temp = TemperatureSensor.rtd_to_temperature(11987)
      assert_in_delta temp, 150.0, 0.5
    end

    test "handles zero ADC value" do
      temp = TemperatureSensor.rtd_to_temperature(0)
      # 0 resistance = very negative temperature
      assert temp < -50.0
    end
  end
end
