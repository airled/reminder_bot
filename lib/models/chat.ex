defmodule ReminderBot.Chat do
  use Ecto.Schema

  schema "chats" do
    has_many :tasks, ReminderBot.Task
    field :telegram_id, :string
    field :timezone, :string
    timestamps()
  end

end
