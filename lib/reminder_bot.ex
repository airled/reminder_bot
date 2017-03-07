defmodule ReminderBot do
  use Application
  import Supervisor.Spec

  def start(_type, _args) do
    children = [
      Plug.Adapters.Cowboy.child_spec(:http, ReminderBot.Router, [], port: 8080),
      supervisor(ReminderBot.Repo, []),
      worker(Redix, [[], [name: :redix]])
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
