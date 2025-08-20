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
end