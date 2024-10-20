defmodule SilviaWeb.HomeTest do
  use SilviaWeb.ConnCase, async: true

  test "disconnected and connected mount", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Dashboard"
  end

end