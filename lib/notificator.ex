defmodule ReminderBot.Notificator do
  @bot_token Application.get_env(:reminder_bot, :token)
  @url "https://api.telegram.org/bot#{@bot_token}/sendMessage"
  @url_update "https://api.telegram.org/bot#{@bot_token}/editMessageText"
  @no_keyboard Poison.encode!(%{remove_keyboard: true})
  @back_button %{text: "выбрать другой день", callback_data: "change_week_0"}
  @empty_markup Poison.encode!(%{})

  def send_to_chat(id, text) do
    HTTPoison.post(@url, {:form, [chat_id: id, text: text, reply_markup: @no_keyboard]})
  end

  def send_days(id, message_id) do
    buttons = get_days_buttons(0)
    more_button = %{text: "дальше", callback_data: "change_week_1"}
    markup = Poison.encode! %{inline_keyboard: [buttons, [more_button]]}
    HTTPoison.post(@url, {:form, [chat_id: id, text: "Выберите день", reply_markup: markup]})
  end

  def send_days(id, message_id, week_shift) do
    buttons = get_days_buttons(week_shift)
    prev_button = %{text: "назад", callback_data: "change_week_#{week_shift - 1}"}
    more_button = %{text: "дальше", callback_data: "change_week_#{week_shift + 1}"}
    markup = Poison.encode! %{inline_keyboard: [buttons, [prev_button, more_button]]}
    update_inline(id, message_id, "Выберите день", markup)
  end

  def send_hours_for_date(id, datetime, message_id) do
    [day, month, year, hour_shift] = String.split(datetime, "/")
    date = "#{day}/#{month}/#{year}"
    case hour_shift do
    "0" ->
      buttons = get_hours_buttons(0..5, date)
      more_button = %{text: "дальше", callback_data: "get_hours_for_#{date}/6"}
      markup = Poison.encode! %{inline_keyboard: [buttons, [more_button], [@back_button]]}
    "6" ->
      buttons = get_hours_buttons(6..11, date)
      prev_button = %{text: "назад", callback_data: "get_hours_for_#{date}/0"}
      more_button = %{text: "дальше", callback_data: "get_hours_for_#{date}/12"}
      markup = Poison.encode! %{inline_keyboard: [buttons, [prev_button, more_button], [@back_button]]}
    "12" ->
      buttons = get_hours_buttons(12..17, date)
      prev_button = %{text: "назад", callback_data: "get_hours_for_#{date}/6"}
      more_button = %{text: "дальше", callback_data: "get_hours_for_#{date}/18"}
      markup = Poison.encode! %{inline_keyboard: [buttons, [prev_button, more_button], [@back_button]]}
    "18" ->
      buttons = get_hours_buttons(18..23, date)
      prev_button = %{text: "назад", callback_data: "get_hours_for_#{date}/12"}
      markup = Poison.encode! %{inline_keyboard: [buttons, [prev_button], [@back_button]]}
    _ ->
      nil
    end
    update_inline(id, message_id, "Выберите час", markup)
  end

  def await_notification_text(datetime, id, message_id) do
    [day, month, year, hour] = String.split(datetime, "/")
    {:ok, connection} = Redix.start_link()
    Redix.command(connection, ["set", id, "#{message_id}/#{day}/#{month}/#{year}/#{hour}"])
    update_inline(id, message_id, "Введите напоминание на #{day}.#{month}.#{year} #{hour}:00 (или /c чтобы отменить)")
  end

  def update_inline(id, message_id, text \\ "...", markup \\ @empty_markup) do
    HTTPoison.post(@url_update,
      {:form, [chat_id: id, message_id: message_id, text: text, reply_markup: markup]}
    )
  end

  defp get_days_buttons(week_shift) do
    Enum.map 0..5, fn day ->
      day = Timex.shift(Timex.now(), days: day, weeks: week_shift)
            |> Timex.format!("%d/%m/%y", :strftime)
      %{text: String.slice(day, 0..4), callback_data: "get_hours_for_#{day}/0"}
    end
  end

  defp get_hours_buttons(range, date) do
    Enum.map range, fn hour ->
      %{text: Integer.to_string(hour), callback_data: "await#{date}/#{hour}"}
    end
  end

end
