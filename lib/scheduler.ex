defmodule ReminderBot.Scheduler do
  import Ecto.Query
  import ReminderBot.Notificator
  alias ReminderBot.Repo, as: DB

  def remind do
    tasks =
      from t in ReminderBot.Task,
      where: t.remind_at < datetime_add(^Ecto.DateTime.utc, 0, "minute")

    DB.all(tasks)
      |> Enum.map(fn task -> run_async_sending(task) end)
      |> Enum.map(fn task -> Task.await(task) end)
  end

  defp run_async_sending(task) do
    Task.async fn ->
      send_to_chat '189503234', task.text
      DB.delete(task)
    end
  end

end
