defmodule ReminderBot.CommandHandler do
  import ReminderBot.Notificator
  alias ReminderBot.Repo, as: DB
  alias ReminderBot.Task
  @redix_namespace Application.get_env(:reminder_bot, :redix_namespace)
  @help_text "Пожалуйста, используйте следующие команды:\n/id - узнать id текущего чата\n/s или /start - добавить новое напоминание"

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
        IO.puts inspect params
    end
  end

  defp handle_command(x, _, _, _) when not is_list(x), do: nil
  defp handle_command([command], id, message_id, text) do
    handle_command([command, nil], id, message_id, text)
  end
  defp handle_command([command, options], id, message_id, text) do
    case command do
      "/id" ->
        clear_user_awaiting(id)
        update_inline(id, message_id - 1)
        send_to_chat(id, id)
      x when x == "/s" or x == "/start" ->
        clear_user_awaiting(id)
        update_inline(id, message_id - 1)
        send_days(id, message_id)
      "/c" ->
        clear_user_awaiting(id)
        update_inline(id, message_id - 1, "Отменено")
      "change_week_" <> week_shift ->
        send_days(id, message_id, (Integer.parse(week_shift) |> elem(0)))
      "get_hours_for_" <> date ->
        send_hours_for_date(id, date, message_id)
      "await" <> datetime ->
        await_notification_text(datetime, id, message_id)
      _ ->
        check_for_awaiting(id, message_id, text)
    end
  end

  defp check_for_awaiting(id, message_id, text) do
    {:ok, value} = Redix.command(:redix, ["get", "#{@redix_namespace}:#{id}"])
    case value do
      x when x == nil or x == "" ->
        update_inline(id, message_id - 1)
        send_to_chat(id, @help_text)
      _ ->

        with [previous_message_id, day, month, year, hour] <- String.split(value, "/"),
             previous_message_id_as_integer <- Integer.parse(previous_message_id) |> elem(0) do

            if message_id == previous_message_id_as_integer + 1 do
              handle_saving({day, month, year, hour}, id, text)
            else
              update_inline(id, message_id - 1)
              send_to_chat(id, @help_text)
            end
            clear_user_awaiting(id)

        else
          _ ->
            update_inline(id, message_id - 1)
            send_to_chat(id, @help_text)
        end

    end
  end

  defp handle_saving({day, month, year, hour}, id, text) do
    padded_hour = String.pad_leading(hour, 2, "0")
    {:ok, remind_at, _} = DateTime.from_iso8601("20#{year}-#{month}-#{day}T#{padded_hour}:00:00Z")
    %Task{text: text, remind_at: remind_at, chat_id: Integer.to_string(id)}
    |> DB.insert
    |> send_saving_result(id)
  end

  defp clear_user_awaiting(id) do
    Redix.command(:redix, ["del", "#{@redix_namespace}:#{id}"])
  end

  defp send_saving_result({:ok, _}, id) , do: send_to_chat(id, "Сохранено")
  defp send_saving_result({_, reason}, id) do
    send_to_chat(id, "Не получилось сохранить (#{inspect reason})")
  end
end
