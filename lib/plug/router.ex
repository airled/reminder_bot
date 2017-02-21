defmodule ReminderBot.Router do
  import ReminderBot.Notificator
  use Plug.Router

  plug Plug.Logger
  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json],
                     pass:  ["text/*"],
                     json_decoder: Poison
  plug :match
  plug :dispatch

  post "/command" do
    try do
      ReminderBot.CommandHandler.handle_connection_request(conn)
    rescue
      e in RuntimeError -> IO.puts("An error occurred: " <> e.message)
    end
    send_resp(conn, 200, "OK")
  end
  
  post "/send" do
    %Plug.Conn{params: params} = conn
    case params do
      %{"id" => id, "text" => text} ->
        send_to_chat(id, text)
        send_resp(conn, 200, "OK")
      _ ->
        send_resp(conn, 200, "Empty")
    end
  end

  match _, do: send_resp(conn, 404, "")
end
