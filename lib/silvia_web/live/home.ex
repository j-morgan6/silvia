defmodule SilviaWeb.Home do
  use SilviaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_title title="Rancilio Silva Dashboard" />
    <.body>
      Coffee machine stuff will show up here!
      <br/><br/>
      This project uses Nerves for RPI hardware integration and LiveView
      for the web interface.
      <br/><br/>
      Click to learn more about
      <.link_to href="https://nerves-project.org">Nerves</.link_to>
      and
      <.link_to href="https://www.phoenixframework.org/">LiveView</.link_to>.
    </.body>
    """
  end
end
