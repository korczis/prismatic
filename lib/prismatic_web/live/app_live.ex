defmodule PrismaticWeb.AppLive do
  use PrismaticWeb, :live_view

  # Import the Layouts module to use the theme_toggle component
  alias PrismaticWeb.Layouts

  @impl true
  @spec mount(any(), any(), any()) :: {:ok, any()}
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  @spec handle_params(any(), any(), any()) :: {:noreply, any()}
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  # Define the theme_toggle component by delegating to Layouts.theme_toggle/1
  def theme_toggle(assigns) do
    Layouts.theme_toggle(assigns)
  end
end
m
