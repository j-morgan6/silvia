defmodule SilviaWeb.Components.Layouts do
  use SilviaWeb.ConnCase, async: true

  test "app layout displays title", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Rancilio Silvia Dashboard"
  end
end