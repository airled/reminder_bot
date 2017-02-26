defmodule ReminderBot.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks) do
      add :text, :string
      add :remind_at, :utc_datetime
      timestamps()
    end
  end
end
