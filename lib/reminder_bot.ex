defmodule ReminderBot do
  use Application

  def start(_type, _args) do
    children = [
      Plug.Adapters.Cowboy.child_spec(:http, ReminderBot.Router, [], port: 8080)
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
