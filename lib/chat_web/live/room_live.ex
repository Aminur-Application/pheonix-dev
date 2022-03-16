defmodule ChatWeb.RoomLive do
  use ChatWeb, :live_view
  require Logger
  require IEx

  @impl true
  def mount(%{"id" => room_id}, _session, socket) do
    topic = topic(room_id)
    user = %{    name: MnemonicSlugs.generate_slug(2),
                 email: MnemonicSlugs.generate_slug(1),
                 id: UUID.uuid4()}
    if connected?(socket) do
      ChatWeb.Endpoint.subscribe(topic)
      ChatWeb.Presence.track(self(), topic, user.name,  default_user_presence_payload(user))
    end
    {:ok, assign(socket,
     room_id: room_id, topic: topic,
     message: "",
     username: user.name,
     messages: [],
     user_list: list_presences(topic)
     )}

  end

  defp topic(room_id), do: "room:#{room_id}"

  defp default_user_presence_payload(user) do
    %{
      typing: false,
      fullname: user.name,
      email: user.email,
      user_id: user.id
    }
  end

  @impl true
  def handle_event("submit_message", %{"chat" => %{"message" => message}}, socket) do
    Logger.info(message: message)
    message = %{uuid: UUID.uuid4(), content: message, username: socket.assigns.username}
    ChatWeb.Endpoint.broadcast(socket.assigns.topic, "new-message", message)
    {:noreply, assign(socket, message: "")}
  end

  @impl true
  def handle_event("stop_typing", %{"value" => value},socket = %{assigns: %{topic: topic, username: username}}) do
    Logger.info(self: username)
    update_presence(self(), topic, username, %{typing: false})
    {:noreply, assign(socket, message: value)}
  end


  @impl true
  def handle_event("form_update",%{"chat" => %{"message" => message}}, socket= %{assigns: %{topic: topic, username: username}}) do
    Logger.info(message: message)
    update_presence(self(), topic, username, %{typing: true})
    {:noreply, assign(socket, message: message)}
  end

  @impl true
  def handle_info(%{event: "new-message", payload: message}, socket) do
    Logger.info(payload: message)

    {:noreply, assign(socket, messages: socket.assigns.messages ++ [message])}
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: %{joins: joins, leaves: leaves}}, socket) do
    Logger.info(Joins: joins |> Map.keys() |> Enum.count, leaves: leaves |> Map.keys() |> Enum.count)
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

    user_list = list_presences(socket.assigns.topic)
    Logger.info(user: user_list, join: join_messages)
    if (joins |> Map.keys() |> Enum.count) != (leaves |> Map.keys() |> Enum.count) do
      {:noreply, assign(socket, messages: join_messages ++ leave_messages, user_list: user_list)}
    else
      {:noreply, assign(socket, user_list: user_list)}
    end
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

  def elipses(typing) do
    if typing do
      ~E"""
      <strong> is typing... </strong>
      """
    end
  end

  def list_presences(topic) do
    ChatWeb.Presence.list(topic)
    |> Enum.map(fn {_user_id, data} ->
      data[:metas]
      |> List.first()
    end)
  end

  def update_presence(pid, topic, key, payload) do
    metas =
      ChatWeb.Presence.get_by_key(topic, key)[:metas]
      |> List.first()
      |> Map.merge(payload)

    ChatWeb.Presence.update(pid, topic, key, metas)
  end
end
