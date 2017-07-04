defmodule ReminderBot.Repo.Migrations.CreateChats do
  use Ecto.Migration

  def change do
    create table(:chats) do
      add :telegram_id, :string
      add :timezone, :string
      timestamps()
    end
    create index(:chats, [:telegram_id], unique: true)
  end
end
