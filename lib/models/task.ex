defmodule ReminderBot.Task do
  use Ecto.Schema

  schema "tasks" do
    field :text, :string
    field :remind_at, :utc_datetime
    field :chat_id, :string
    timestamps
  end

end
