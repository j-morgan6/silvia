defmodule Silvia.Hardware.RelayTest do
  use ExUnit.Case, async: true

  alias Silvia.Hardware.Relay

  @default_pin 18

  setup do
    # Set the test module to receive fake messages
    Application.put_env(:silvia, :gpio_test_pid, self())
    # Start the relay process
    start_supervised!({Relay, []})
    :ok
  end

  describe "initialization" do
    test "starts with default pin" do
      assert_received {:gpio_open, @default_pin, :output}
      # Should initialize in OFF state
      assert_received {:gpio_write, @default_pin, 0}
    end

    test "starts with custom pin" do
      stop_supervised!(Relay)
      custom_pin = 23
      start_supervised!({Relay, [pin: custom_pin]}, restart: :temporary)
      assert_received {:gpio_open, ^custom_pin, :output}
      assert_received {:gpio_write, ^custom_pin, 0}
    end
  end

  describe "relay control" do
    test "turns on the relay" do
      :ok = Relay.on()
      assert_received {:gpio_write, @default_pin, 1}
      assert Relay.state() == :on
    end

    test "turns off the relay" do
      # First turn it on
      :ok = Relay.on()
      assert_received {:gpio_write, @default_pin, 1}

      # Then turn it off
      :ok = Relay.off()
      assert_received {:gpio_write, @default_pin, 0}
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

      # Reset the GPIO module
      Application.put_env(:silvia, :gpio_module, Fake.GPIO)
    end
  end

  describe "cleanup" do
    test "closes GPIO on termination" do
      pid = Process.whereis(Relay)
      GenServer.stop(pid)
      assert_received {:gpio_write, @default_pin, 0}  # Should turn off first
      assert_received {:gpio_close, @default_pin}     # Then close the GPIO
    end
  end
end
