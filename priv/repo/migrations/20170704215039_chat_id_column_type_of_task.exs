defmodule ReminderBot.Repo.Migrations.ChatIdColumnTypeOfTask do
  use Ecto.Migration

  def up do
    alter table(:tasks) do
      remove :chat_id
      add :chat_id, :integer
    end
  end

  def down do
    alter table(:tasks) do
      remove :chat_id
      add :chat_id, :string
    end
  end
end
