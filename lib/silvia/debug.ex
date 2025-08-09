defmodule Debug do
  def print(term, label \\ "Debug") do
    IO.inspect(term, label: label, pretty: true, syntax_colors: IO.ANSI.syntax_colors())
  end
end
