defmodule ReminderBot.Repo.Migrations.AddChatIdToTask do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :chat_id, :string
    end
  end
end
