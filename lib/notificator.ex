defmodule ReminderBot.Notificator do
  @bot_token Application.get_env(:reminder_bot, :token)
  @url "https://api.telegram.org/bot#{@bot_token}/sendMessage"
  @no_keyboard Poison.encode!(%{remove_keyboard: true})

  def send_to_chat(id, text) do
    HTTPoison.post(@url, {:form, [chat_id: id, text: text, reply_markup: @no_keyboard]})
  end

  def send_to_chat_with_keyboard(id, keyboard_list) do
    buttons = Enum.map keyboard_list, fn button_text ->
      %{text: button_text, callback_data: button_text}
    end
    markup = Poison.encode! %{inline_keyboard: [buttons], resize_keyboard: true}
    HTTPoison.post(@url, {:form, [chat_id: id, text: "Блабла", reply_markup: markup]})
  end

end
