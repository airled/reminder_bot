defmodule ReminderBot.Notificator do
  @bot_token Application.get_env(:reminder_bot, :token)

  def send_to_chat(id, text) do
    "https://api.telegram.org/bot#{@bot_token}/sendMessage?chat_id=#{id}&text=#{text}"
    |> URI.encode
    |> HTTPoison.get!
  end

end
