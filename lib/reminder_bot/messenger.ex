defmodule ReminderBot.Messenger do
  import Ecto.Query
  alias ReminderBot.Repo

  @bot_token Application.get_env(:reminder_bot, :token)
  @redix_namespace Application.get_env(:reminder_bot, :redix_namespace)
  @url "https://api.telegram.org/bot#{@bot_token}/sendMessage"
  @url_update "https://api.telegram.org/bot#{@bot_token}/editMessageText"
  @url_delete "https://api.telegram.org/bot#{@bot_token}/deleteMessage"
  @back_button %{text: "выбрать другой день", callback_data: "change_week_0"}
  @cancel_button %{text: "отменить", callback_data: "/c"}
  @empty_markup Poison.encode!(%{})
  @no_keyboard_markup Poison.encode!(%{remove_keyboard: true})

  def send_to_chat(text, chat, markup \\ @no_keyboard_markup) do
    HTTPoison.post(@url, {
      :form, [chat_id: chat.telegram_id, text: text, reply_markup: markup]
    })
  end

  def update_inline(chat, message_id, text \\ "...", markup \\ @empty_markup) do
    HTTPoison.post(@url_update, {
      :form, [chat_id: chat.telegram_id, message_id: message_id, text: text, reply_markup: markup]
    })
  end

  def delete_message(chat, message_id) do
    HTTPoison.post(@url_delete, {
      :form, [chat_id: chat.telegram_id, message_id: message_id]
    })
  end

  def send_days(chat) do
    more_button = %{text: "дальше", callback_data: "change_week_1"}
    markup = get_days_buttons(chat)
             |> Enum.concat([ [more_button], [@cancel_button] ])
             |> build_inline_markup
    send_to_chat("Выберите день", chat, markup)
  end

  def send_days(chat, message_id, week_shift) do
    prev_button = %{text: "назад",  callback_data: "change_week_#{week_shift - 1}"}
    more_button = %{text: "дальше", callback_data: "change_week_#{week_shift + 1}"}
    markup = get_days_buttons(chat, week_shift)
             |> Enum.concat([ [prev_button, more_button], [@cancel_button] ])
             |> build_inline_markup
    update_inline(chat, message_id, "Выберите день", markup)
  end

  def send_hours_for_date(chat, datetime, message_id) do
    [day, month, year, hour_shift] = String.split(datetime, "/")
    date = "#{day}/#{month}/#{year}"
    case hour_shift do
    "0" ->
      more_button = %{text: "дальше", callback_data: "get_hours_for_#{date}/12"}
      markup = get_hours_buttons(0..11, date)
               |> Enum.concat([ [more_button], [@cancel_button, @back_button] ])
               |> build_inline_markup
    "12" ->
      prev_button = %{text: "назад", callback_data: "get_hours_for_#{date}/0"}
      markup = get_hours_buttons(12..23, date)
               |> Enum.concat([ [prev_button], [@cancel_button, @back_button] ])
               |> build_inline_markup
    _ ->
      nil
      markup = @empty_markup
    end
    update_inline(chat, message_id, "Выберите час на #{day}.#{month}", markup)
  end

  def send_await_notification_text(datetime, chat, message_id) do
    [day, month, year, hour] = String.split(datetime, "/")
    Redix.command(:redix,
      [
        "set",
        "#{@redix_namespace}:#{chat.telegram_id}",
        "#{message_id}/#{day}/#{month}/#{year}/#{hour}"
      ]
    )
    update_inline(chat, message_id, "Введите напоминание на #{day}.#{month}.#{year} #{hour}:00 (или /c чтобы отменить)")
  end

  def send_list(chat) do
    ReminderBot.Task
    |> where(chat_id: ^chat.id)
    |> order_by(:remind_at)
    |> Repo.all
    |> Enum.reduce("", fn(task, memo) -> memo <> "#{task.remind_at} | #{task.text}\n" end)
    |> String.replace(":00.000000Z", "")
    |> send_to_chat(chat)
  end

  def send_timezones(chat) do
    positives = Enum.map(0..12, fn zone -> String.pad_leading("#{zone}", 3, ["+", "0"]) end)
    negatives = Enum.map(12..1, fn zone -> String.pad_leading("#{zone}", 3, ["-", "0"]) end)
    markup =
      negatives
      |> Enum.concat(positives)
      |> Enum.map(fn zone -> %{text: "UTC#{zone}", callback_data: "set_zone_#{zone}"} end)
      |> Enum.chunk(5)
      |> Enum.concat([ [@cancel_button] ])
      |> build_inline_markup
    send_to_chat("Выберите часовой пояс", chat, markup)
  end

  defp get_days_buttons(chat, week_shift \\ 0) do
    buttons = Enum.map 0..7, fn day ->
      day = Timex.shift(Timex.now(chat.timezone), days: day, weeks: week_shift)
            |> Timex.format!("%d/%m/%y", :strftime)
      %{text: String.slice(day, 0..4), callback_data: "get_hours_for_#{day}/0"}
    end
    Enum.chunk(buttons, 4)
  end

  defp get_hours_buttons(range, date) do
    buttons = Enum.map range, fn hour ->
      text = hour
             |> Integer.to_string
             |> String.pad_leading(2, "0")
      %{text: text, callback_data: "await#{date}/#{hour}"}
    end
    Enum.chunk(buttons, 6)
  end

  defp build_inline_markup(buttons) do
    Poison.encode! %{inline_keyboard: buttons}
  end
end
