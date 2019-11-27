defmodule Easydbio do
  @moduledoc """
  Hackney hold-connection gen-server for easydbio
  """

  @app_url "https://app.easydb.io/"

  use GenServer

  def start_link(uuid, token, opts \\ []) do
    GenServer.start_link(
      __MODULE__, 
      %{uuid: uuid, token: token, conn: nil},
      opts
    )
  end

  def init(state) do
    :hackney.connect(:hackney_ssl, @app_url, 443, [])
    |> case do
      {:ok, conn} -> {:ok, %{state | conn: conn}}
      {:error, reason} -> {:error, reason}
    end
  end

  def handle_call({:get, key}, %{uuid: uuid, token: token, conn: conn} = state) do
    req = {:get, "/database/#{uuid}/#{key}", [{"token", token}], ""}
    send_req(conn, req, state)
  end

  def handle_call(:list, %{uuid: uuid, token: token, conn: conn} = state) do
    req = {:get, "/database/#{uuid}", [{"token", token}], ""}
    send_req(conn, req, state)
  end

  def handle_cast({:put, key, value}, %{uuid: uuid, token: token, conn: conn} = state) do
    headers = [
      {"content-type", "application/json"},
      {"token", token}
    ]
    req = {:delete, "database/#{uuid}", headers, "{\"key\":\"#{key}\",\"value\":\"#{value}\"}"}
    send_req(conn, req, state)
  end

  def handle_cast({:delete, key}, %{uuid: uuid, token: token, conn: conn} = state) do
    headers = [
      {"content-type", "application/json"},
      {"token", token}
    ]
    req = {:delete, "database/#{uuid}", headers, "{\"key\":\"#{key}\"}"}
    send_req(conn, req, state)
  end

  defp send_req(conn, req, state) do
    case :hackney.send_request(conn, req) do
      {:ok, _, _, conn} ->
        case :hackney.body(conn) do
          {:ok, body} -> {:reply, body, %{state | conn: conn}}
          _ -> {:stop, :shutdown, state}
        end
      _ -> {:stop, :shutdown, state}
    end
  end

end
