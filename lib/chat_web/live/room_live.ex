defmodule ChatWeb.RoomLive do
  use ChatWeb, :live_view
  require Logger

  @impl true
  def mount(%{"id" => room_id}, _session, socket) do
    topic = topic(room_id)
    username = MnemonicSlugs.generate_slug(2)
    if connected?(socket) do
      ChatWeb.Endpoint.subscribe(topic)
      ChatWeb.Presence.track(self(), topic, username, %{typing: false})
    end
    {:ok, assign(socket,
     room_id: room_id, topic: topic,
     message: "",
     username: username,
     messages: [],
     user_list: []
     )}
  end

  defp topic(room_id), do: "room:#{room_id}"

  @impl true
  def handle_event("submit_message", %{"chat" => %{"message" => message}}, socket) do
    Logger.info(message: message)
    message = %{uuid: UUID.uuid4(), content: message, username: socket.assigns.username}
    ChatWeb.Endpoint.broadcast(socket.assigns.topic, "new-message", message)
    {:noreply, assign(socket, message: "")}
  end

  @impl true
  def handle_event("form_update",%{"chat" => %{"message" => message}}, socket= %{assigns: %{topic: topic, username: username}}) do
    Logger.info(message: message)
    
    {:noreply, assign(socket, message: message)}
  end

  @impl true
  def handle_info(%{event: "new-message", payload: message}, socket) do
    Logger.info(payload: message)

    {:noreply, assign(socket, messages: socket.assigns.messages ++ [message])}
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: %{joins: joins, leaves: leaves}}, socket) do
    Logger.info(Joins: joins, leaves: leaves)
    join_messages =
    joins
    |> Map.keys()
    |> Enum.map(fn username ->
                    %{type: :system, uuid: UUID.uuid4(), content: "#{username} joined"}
                  end)

    leave_messages =
    leaves
    |> Map.keys()
    |> Enum.map(fn username ->
                    %{type: :system, uuid: UUID.uuid4(), content: "#{username} left"}
                  end)
    user_list = ChatWeb.Presence.list(socket.assigns.topic)|> Map.keys()

    {:noreply, assign(socket, messages: join_messages ++ leave_messages, user_list: user_list)}
  end

  def display_message(%{type: :system, uuid: uuid, content: content}) do
    ~E"""
    <p id="<%= uuid %>"><em><%= content %></em></p>
    """
  end

  def display_message(%{username: username, uuid: uuid, content: content}) do
      ~E"""
      <p id="<%= uuid %>"><strong><%= username %></strong>:
      <%= content %></p>
      """
  end
end
