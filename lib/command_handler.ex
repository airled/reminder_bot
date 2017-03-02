defmodule ReminderBot.CommandHandler do
  import Ecto.Query
  import ReminderBot.Notificator
  alias ReminderBot.Repo, as: DB
  alias ReminderBot.Task
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
        send_to_chat(id, id)
      "/s"  ->
        clear_user_awaiting(id)
        send_initial_calendar_for_month(id, message_id)
      "change_week_" <> week_shift ->
        send_calendar_for_month(id, message_id, (Integer.parse(week_shift) |> elem(0)))
      "get_hours_for_" <> date ->
        send_hours_for_date(id, date, message_id)
      "await" <> datetime ->
        await_notification_text(datetime, id, message_id)
      _ ->
        check_for_awaiting(id, message_id, text)
    end
  end

  defp check_for_awaiting(id, message_id, text) do
    {:ok, connection} = Redix.start_link()
    {:ok, value} = Redix.command(connection, ["get", id])
    case value do
      nil ->
        send_to_chat(id, @help_text)
      "" ->
        send_to_chat(id, @help_text)
      _ ->

        with [previous_message_id, day, month, year, hour] <- String.split(value, "/"),
             previous_message_id_as_integer <- Integer.parse(previous_message_id) |> elem(0) do

            if message_id == previous_message_id_as_integer + 1 do
              handle_saving({day, month, year, hour}, id, text)
            else
              send_to_chat(id, @help_text)
            end
            clear_user_awaiting(id)

        else
          _ -> send_to_chat(id, @help_text)
        end

    end
  end

  defp handle_saving({day, month, year, hour}, id, text) do
    padded_hour = String.pad_leading(hour, 2, "0")
    {:ok, remind_at, _} = DateTime.from_iso8601("20#{year}-#{month}-#{day}T#{padded_hour}:00:00Z")
    %Task{text: text, remind_at: remind_at}
      |> DB.insert
      |> send_saving_result(id)
  end

  defp clear_user_awaiting(id) do
    {:ok, connection} = Redix.start_link()
    {:ok, value} = Redix.command(connection, ["set", id, ""])
  end

  defp send_saving_result({:ok, _}, id) , do: send_to_chat(id, "Сохранено")
  defp send_saving_result({_, reason}, id) do
    send_to_chat(id, "Не получилось сохранить (#{inspect reason})")
  end
end
