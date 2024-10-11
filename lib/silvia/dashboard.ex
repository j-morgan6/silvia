defmodule Silvia.Dashboard do
  def temperature do
    Enum.random(94..96)
  end

  def brew_temperature do
    Enum.random(92..98)
  end

  def steam_temperature do
    Enum.random(135..145)
  end
end