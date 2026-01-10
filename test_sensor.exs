# TSIC306 Hardware Test Script
# Run this on the Raspberry Pi with: elixir test_sensor.exs

IO.puts("=== TSIC306 Hardware Test ===\n")
IO.puts("Date: #{DateTime.utc_now() |> DateTime.to_string()}\n")

# Test 1: Basic Connectivity
IO.puts("Test 1: Basic Connectivity")
IO.puts("---------------------------")

case Silvia.Hardware.HeatSensor.get_temperature() do
  {:ok, temp} ->
    IO.puts("✓ Sensor responding")
    IO.puts("  Current temperature: #{Float.round(temp, 2)}°C")

  {:error, :sensor_timeout} ->
    IO.puts("✗ FAIL: Sensor timeout")
    IO.puts("  Check: VDD (3.3V), GND, Signal (GPIO 4)")
    System.halt(1)

  {:error, reason} ->
    IO.puts("✗ FAIL: #{inspect(reason)}")
    System.halt(1)
end

IO.puts("")

# Test 2: Continuous Reading (10 samples)
IO.puts("Test 2: Continuous Reading (10 samples)")
IO.puts("----------------------------------------")

readings = for i <- 1..10 do
  Process.sleep(1000)
  case Silvia.Hardware.HeatSensor.get_temperature() do
    {:ok, temp} ->
      IO.puts("  #{i}. #{Float.round(temp, 2)}°C")
      temp
    {:error, reason} ->
      IO.puts("  #{i}. Error: #{inspect(reason)}")
      nil
  end
end

valid_readings = Enum.reject(readings, &is_nil/1)
success_rate = (length(valid_readings) / 10.0) * 100

IO.puts("\nResults:")
IO.puts("  Success rate: #{Float.round(success_rate, 1)}%")

if length(valid_readings) > 0 do
  avg = Enum.sum(valid_readings) / length(valid_readings)
  min = Enum.min(valid_readings)
  max = Enum.max(valid_readings)
  range = max - min

  IO.puts("  Average: #{Float.round(avg, 2)}°C")
  IO.puts("  Min: #{Float.round(min, 2)}°C")
  IO.puts("  Max: #{Float.round(max, 2)}°C")
  IO.puts("  Range: #{Float.round(range, 2)}°C")

  if success_rate >= 99.0 do
    IO.puts("  ✓ PASS: Success rate > 99%")
  else
    IO.puts("  ✗ FAIL: Success rate < 99%")
  end

  if range < 1.0 do
    IO.puts("  ✓ PASS: Stable readings (range < 1°C)")
  else
    IO.puts("  ⚠ WARNING: High variance (range > 1°C)")
  end
else
  IO.puts("  ✗ FAIL: No valid readings")
  System.halt(1)
end

IO.puts("\n=== Test Complete ===")
IO.puts("\nNext steps:")
IO.puts("1. Verify temperature is reasonable for room temperature (18-25°C)")
IO.puts("2. Test with ice water (should read ~0°C)")
IO.puts("3. Test with hot water (should read 60-80°C)")
IO.puts("4. Run longer test: for i <- 1..600, do: ... (10 minutes)")
