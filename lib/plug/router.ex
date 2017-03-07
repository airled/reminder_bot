defmodule ReminderBot.Router do
  use Plug.Router

  plug Plug.Logger
  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json],
                     pass:  ["text/*"],
                     json_decoder: Poison
  plug :match
  plug :dispatch

  post "/command" do
    try do
      Task.start(ReminderBot.CommandHandler, :handle_connection_request, [conn])
    rescue
      e in RuntimeError -> IO.puts("An error occurred: " <> e.message)
    end
    send_resp(conn, 200, "OK")
  end

  match _, do: send_resp(conn, 404, "")
end
