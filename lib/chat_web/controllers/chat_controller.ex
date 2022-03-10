defmodule ChatWeb.ChatController do
  use ChatWeb, :controller

  plug :action

  def index(conn, _params) do
    render conn, "index.html"
  end
end
