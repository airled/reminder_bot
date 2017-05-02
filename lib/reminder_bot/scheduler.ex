defmodule ReminderBot.Scheduler do
  import Ecto.Query
  import ReminderBot.Messenger
  alias ReminderBot.Repo

  def remind do
    ReminderBot.Task
    |> where([t], t.remind_at < ^Timex.now)
    |> Repo.all
    |> Enum.map(fn task -> run_async_sending(task) end)
    |> Enum.map(fn task -> Task.await(task) end)
  end

  defp run_async_sending(task) do
    Task.async fn ->
      send_to_chat task.text, task.chat_id
      Repo.delete(task)
    end
  end

end
