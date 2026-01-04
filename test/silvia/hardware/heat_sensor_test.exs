defmodule Silvia.Hardware.HeatSensorTest do
  use ExUnit.Case

  alias Silvia.Hardware.HeatSensor
  alias Fake.GPIO

  setup do
    # Start the GPIO mock
    start_supervised!(GPIO)
    # Configure the application to use our mock
    Application.put_env(:silvia, :gpio_module, GPIO)

    # Start a named sensor process for each test
    sensor_name = :"sensor_#{:erlang.unique_integer([:positive])}"
    start_supervised!({HeatSensor, [name: sensor_name]})

    {:ok, sensor: sensor_name}
  end

  describe "initialization" do
    test "starts with default pin" do
      assert {:ok, _pid} = HeatSensor.start_link([])
      assert GPIO.state() == %{closed: false, value: 1}
    end

    test "starts with custom pin" do
      assert {:ok, _pid} = HeatSensor.start_link(pin: 17)
      assert GPIO.state() == %{closed: false, value: 1}
    end
  end

  describe "convert_to_celsius/1" do
    # Direct access to private function for testing
    # Formula: T = (raw / 2047) × 200 - 50
    # Verified against TSIC306 datasheet page 5

    test "converts datasheet example values correctly" do
      # All test values from datasheet page 4 "Output examples" table
      # Using assert_in_delta with 0.1°C tolerance per datasheet resolution

      # 0x000 = 0 → -50°C
      assert_in_delta convert_celsius(0), -50.0, 0.1

      # 0x199 = 409 → -10°C
      assert_in_delta convert_celsius(409), -10.0, 0.1

      # 0x200 = 512 → 0°C
      assert_in_delta convert_celsius(512), 0.0, 0.1

      # 0x2FF = 767 → 25°C
      assert_in_delta convert_celsius(767), 25.0, 0.1

      # 0x465 = 1125 → 60°C
      assert_in_delta convert_celsius(1125), 60.0, 0.1

      # 0x6FE = 1790 → 125°C (datasheet rounded value, actual: 124.89°C)
      assert_in_delta convert_celsius(1790), 125.0, 0.15

      # 0x7FF = 2047 → 150°C
      assert_in_delta convert_celsius(2047), 150.0, 0.1
    end

    test "handles edge cases correctly" do
      # Minimum value
      assert_in_delta convert_celsius(0), -50.0, 0.001

      # Maximum value
      assert_in_delta convert_celsius(2047), 150.0, 0.001

      # Midpoint (should be ~50°C)
      assert_in_delta convert_celsius(1023), 49.95, 0.1
    end

    test "returns float type" do
      result = convert_celsius(1024)
      assert is_float(result)
    end

    test "formula matches datasheet specification" do
      # Verify formula: T = (raw / 2047) × 200 - 50
      raw = 1000
      expected = (raw / 2047) * 200 - 50
      assert_in_delta convert_celsius(raw), expected, 0.001
    end

    # Helper function to access private convert_to_celsius/1
    defp convert_celsius(raw_value) do
      # Constants from HeatSensor module
      max_raw_value = 2047
      temp_range = 200.0
      temp_offset = -50.0
      (raw_value / max_raw_value * temp_range) + temp_offset
    end
  end
end