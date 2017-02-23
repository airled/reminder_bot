defmodule ReminderBot.CommandHandler do
  import ReminderBot.Notificator
  @help_text "Пожалуйста, используйте следующие команды:\nid - узнать id текущего чата"

  def handle_connection_request(%Plug.Conn{params: params} = conn) do
    case params do
      %{"message" => %{"chat" => %{"id" => id}, "text" => text}} ->
        text
        |> String.replace("  ", " ")
        |> String.split(" ", parts: 2)
        |> handle_command(id)
      %{"callback_query" => %{"data" => data, "message" => %{"chat" => %{"id" => id}, "text" => text}}} ->
        handle_command([data], id)
      _ ->
        IO.puts inspect params
    end
  end

  defp handle_command(x, _) when not is_list(x), do: nil
  defp handle_command([command], id), do: handle_command([command, nil], id)
  defp handle_command([command, options], id) do
    case command do
      "/id" -> send_to_chat(id, id)
      "/i"  -> send_to_chat_with_keyboard(id, ["/s", "/w", "/d"])
      "/s"  -> handle_saving(options, id)
      "/w"  -> handle_watching(options, id)
      "/d"  -> handle_deleting(options, id)
          _ -> send_to_chat(id, @help_text)
    end
  end

  defp handle_saving(nil, id), do: send_to_chat id, "Не введены опции"
  defp handle_saving(options, id) when is_binary(options) do
    splitted_options = String.split(options, " ", parts: 3)
    case splitted_options do
      [date, time, text] ->
        {:ok, connection} = Redix.start_link()
        Redix.command(connection, ["rpush", date <> time, text])
        |> send_result(id)
      _ ->
        send_to_chat id, "Ошибочный ввод"
    end
  end

  defp handle_watching(nil, id), do: send_to_chat id, "Не введены опции"
  defp handle_watching(options, id) when is_binary(options) do
    splitted_options = String.split(options, " ", parts: 2)
    case splitted_options do
      [date, time] ->
        {:ok, connection} = Redix.start_link()
        Redix.command(connection, ["lrange", date <> time, "0", "-1"])
        |> send_result(id)
      _ ->
        send_to_chat id, "Ошибочный ввод"
    end
  end

  defp handle_deleting(nil, id), do: send_to_chat id, "Не введены опции"
  defp handle_deleting(options, id) when is_binary(options) do
    splitted_options = String.split(options, " ", parts: 2)
    case splitted_options do
      [date, time] ->
        {:ok, connection} = Redix.start_link()
        Redix.command(connection, ["del", date <> time])
        |> send_result(id)
      _ ->
        send_to_chat id, "Ошибочный ввод"
    end
  end

  def send_result({:ok, value}, id) when is_integer(value), do: send_to_chat(id, "OK")
  def send_result({:ok, value}, id) when is_list(value), do: send_to_chat(id, inspect(value))
  def send_result({_, reason}, id) do
    send_to_chat(id, "Не получилось сохранить (#{inspect reason})")
  end
end