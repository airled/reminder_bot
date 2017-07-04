defmodule ReminderBot.Task do
  use Ecto.Schema

  schema "tasks" do
    belongs_to :chat, ReminderBot.Chat
    field :text, :string
    field :remind_at, :utc_datetime
    timestamps()
  end

end
