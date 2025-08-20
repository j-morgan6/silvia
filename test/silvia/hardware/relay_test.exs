defmodule Silvia.Hardware.RelayTest do
  use ExUnit.Case

  alias Silvia.Hardware.Relay
  alias Fake.GPIO

  setup do
    # Start the GPIO mock
    start_supervised!(GPIO)
    # Configure the application to use our mock
    Application.put_env(:silvia, :gpio_module, GPIO)

    # Start a named sensor process for each test
    relay_name = :"relay_#{:erlang.unique_integer([:positive])}"
    start_supervised!({Relay, [name: relay_name]})

    {:ok, relay: relay_name}
  end

  describe "initialization" do
    test "starts with default pin" do
      stop_supervised!(Relay)
      assert {:ok, _pid} = Relay.start_link([])
      assert Relay.state() == :off
      assert GPIO.state() == %{closed: false, value: 0}
    end

    test "starts with custom pin" do
      stop_supervised!(Relay)
      custom_pin = 23
      assert {:ok, _pid} = Relay.start_link(pin: custom_pin)
      assert Relay.state() == :off
      assert GPIO.state() == %{closed: false, value: 0}
    end
  end

  describe "relay control" do
    test "turns on the relay" do
      :ok = Relay.on()
      assert Relay.state() == :on
      assert GPIO.state() == %{closed: false, value: 1}
    end

    test "turns off the relay" do
      # First turn it on
      :ok = Relay.on()
      assert GPIO.state() == %{closed: false, value: 1}

      # Then turn it off
      :ok = Relay.off()
      assert GPIO.state() == %{closed: false, value: 0}
      assert Relay.state() == :off
    end

    test "maintains state between operations" do
      assert Relay.state() == :off

      :ok = Relay.on()
      assert Relay.state() == :on

      :ok = Relay.on()  # Calling on again
      assert Relay.state() == :on  # Should still be on

      :ok = Relay.off()
      assert Relay.state() == :off

      :ok = Relay.off()  # Calling off again
      assert Relay.state() == :off  # Should still be off
    end
  end

  describe "error handling" do
    test "handles GPIO initialization failure" do
      # Define a failing GPIO mock module inline
      defmodule FailingGPIOMock do
        def open(_pin, _direction), do: {:error, :failed_to_open}
      end

      # Temporarily replace the GPIO module
      Application.put_env(:silvia, :gpio_module, FailingGPIOMock)

      assert {:error, _} = Relay.start_link([])
    end
  end

  describe "cleanup" do
    test "closes GPIO on termination" do
      pid = Process.whereis(Relay)
      GenServer.stop(pid)
      assert GPIO.state() == %{closed: true, value: 0}
    end
  end
end
