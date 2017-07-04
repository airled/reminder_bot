defmodule ReminderBot.CommandHandler do
  import ReminderBot.Messenger
  alias ReminderBot.Repo
  alias ReminderBot.Chat
  alias ReminderBot.Task
  @redix_namespace Application.get_env(:reminder_bot, :redix_namespace)
  @help_text "Пожалуйста, используйте следующие команды:\n/s или /start - добавить новое напоминание\n/l или /list - посмотреть список своих будущих напоминаний\n/tz или /timezone - настрока своей таймзоны"

  def handle_connection_request(%Plug.Conn{params: params} = conn) do
    case params do
      %{"message" => %{"chat" => %{"id" => id}, "text" => text, "message_id" => message_id}} ->
        text
        |> String.replace("  ", " ")
        |> String.split(" ", parts: 2)
        |> handle_command(id, message_id, text)
      %{"callback_query" => %{
        "data" => data,
        "message" => %{"chat" => %{"id" => id}, "text" => text, "message_id" => message_id}
      }} ->
        handle_command([data], id, message_id, text)
      _ ->
        IO.inspect params
    end
  end

  defp handle_command(x, _, _, _) when not is_list(x), do: nil
  defp handle_command([command], id, message_id, text) do
    handle_command([command, nil], id, message_id, text)
  end
  defp handle_command([command, options], id, message_id, text) do
    chat = save_chat(id)
    case command do
      command when command == "/s" or command == "/start" ->
        clear_user_awaiting(chat)
        delete_message(chat, message_id - 1)
        send_days(chat)
      command when command == "/l" or command == "/list" ->
        clear_user_awaiting(chat)
        delete_message(chat, message_id - 1)
        send_list(chat)
      command when command == "/tz" or command == "/timezone" ->
        clear_user_awaiting(chat)
        delete_message(chat, message_id - 1)
        send_timezones(chat)
      "/c" ->
        clear_user_awaiting(chat)
        delete_message(chat, message_id - 1)
        delete_message(chat, message_id)
      "set_zone_" <> zone ->
        Ecto.Changeset.change(chat, timezone: "#{zone}:00") |> Repo.update!
        delete_message(chat, message_id)
        send_to_chat("Выбран часовой пояс #{zone}", chat)
      "change_week_" <> week_shift ->
        send_days(chat, message_id, String.to_integer(week_shift))
      "get_hours_for_" <> date ->
        send_hours_for_date(chat, date, message_id)
      "await" <> datetime ->
        send_await_notification_text(datetime, chat, message_id)
      _ ->
        check_for_awaiting(chat, message_id, text)
    end
  end

  defp check_for_awaiting(chat, message_id, text) do
    {:ok, value} = Redix.command(:redix, ["get", "#{@redix_namespace}:#{chat.telegram_id}"])
    case value do
      x when x == nil or x == "" ->
        delete_message(chat, message_id - 1)
        send_to_chat(@help_text, chat)
      _ ->

        with [previous_message_id, day, month, year, hour] <- String.split(value, "/"),
             previous_message_id_as_integer <- String.to_integer(previous_message_id) do

            if message_id == previous_message_id_as_integer + 1 do
              handle_saving({day, month, year, hour}, chat, text)
            else
              delete_message(chat, message_id - 1)
              send_to_chat(@help_text, chat)
            end
            clear_user_awaiting(chat)

        else
          _ ->
            delete_message(chat, message_id - 1)
            send_to_chat(@help_text, chat)
        end

    end
  end

  defp handle_saving({day, month, year, hour}, chat, text) do
    padded_hour = String.pad_leading(hour, 2, "0")
    IO.inspect "20#{year}-#{month}-#{day}T#{padded_hour}:00:00#{chat.timezone}"
    {:ok, remind_at, _} = DateTime.from_iso8601("20#{year}-#{month}-#{day}T#{padded_hour}:00:00#{chat.timezone}")
    %Task{text: text, remind_at: remind_at, chat_id: chat.id}
    |> Repo.insert
    |> send_saving_result(chat)
  end

  defp clear_user_awaiting(chat) do
    Redix.command(:redix, ["del", "#{@redix_namespace}:#{chat.telegram_id}"])
  end

  defp send_saving_result({:ok, _}, chat) , do: send_to_chat("Сохранено", chat)
  defp send_saving_result({_, reason}, chat) do
    send_to_chat(chat, "Не получилось сохранить (#{inspect reason})")
  end

  defp save_chat(telegram_id) do
    chat = Repo.get_by(Chat, telegram_id: Integer.to_string(telegram_id))
    case chat do
      nil
        -> Repo.insert!(%Chat{telegram_id: Integer.to_string(telegram_id), timezone: "+00:00"})
      _
        -> chat
    end
  end
end
