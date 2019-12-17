defmodule Easydbio do
  @moduledoc """
  Hackney hold-connection GenServer for easydbio
  """

  @app_url "app.easydb.io"

  use GenServer

  @type edb_server :: pid() | {:global, any()} | Atom.t() | {:local, Atom.t()}
  @type key :: String.t() | Integer.t() | Float.t()
  @type value :: String.t() | Integer.t() | Float.t() | [value(), ...]

  @doc """
  Gets the value from the specified server
  returns `value`
  """
  @spec get(edb_server(), key()) :: value()
  def get(edb_server, key) do
    GenServer.call(edb_server, {:edb_get, key})
  end

  @doc """
  Puts the value onto the specified server
  returns `:ok`
  """
  @spec put(edb_server(), key(), value()) :: :ok
  def put(edb_server, key, value) do
    GenServer.cast(edb_server, {:edb_put, key, value})
  end

  @doc """
  Lists all values on the specified server
  returns `Map.t()`
  """
  @spec list(edb_server()) :: Map.t()
  def list(edb_server) do
    GenServer.call(edb_server, :edb_list)
  end

  @doc """
  Deletes the value on the specified server
  returns `:ok`
  """
  @spec delete(edb_server(), key()) :: value()
  def delete(edb_server, key) do
    GenServer.cast(edb_server, {:delete, key})
  end

  # Private API

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

  def handle_call({:edb_get, key}, _, %{uuid: uuid, token: token, conn: conn} = state) do
    req = {:get, "/database/#{uuid}/#{key}", [{"token", token}], ""}
    send_req_reply(conn, req, state)
  end

  def handle_call(:edb_list, _, %{uuid: uuid, token: token, conn: conn} = state) do
    req = {:get, "/database/#{uuid}", [{"token", token}], ""}
    send_req_reply(conn, req, state)
  end

  #TODO body encoding optimization without Jason
  def handle_cast({:edb_put, key, value}, %{uuid: uuid, token: token, conn: conn} = state) do
    headers = [
      {"content-type", "application/json"},
      {"token", token}
    ]
    body = %{key: key, value: value} |> Jason.encode!
    req = {:post, "/database/#{uuid}", headers, body}
    send_req_noreply(conn, req, state)
  end

  def handle_cast({:edb_delete, key}, %{uuid: uuid, token: token, conn: conn} = state) do
    headers = [
      {"content-type", "application/json"},
      {"token", token}
    ]
    body = %{key: key} |> Jason.encode!
    req = {:delete, "/database/#{uuid}", headers, body}
    send_req_noreply(conn, req, state)
  end

  # Helpers

  defp send_req_reply(conn, req, state) do
    case :hackney.send_request(conn, req) do
      {:ok, 200, _, conn} ->
        case :hackney.body(conn) do
          {:ok, body} -> {:reply, Jason.decode!(body), %{state | conn: conn}}
          _ -> {:stop, :shutdown, state}
        end
      _ -> {:stop, :shutdown, state}
    end
  end

  defp send_req_noreply(conn, req, state) do
    case :hackney.send_request(conn, req) do
      {:ok, 200, _, conn} = res ->
        {:noreply, %{state | conn: conn}}
      _ -> 
        {:stop, :shutdown, state}
    end
  end
end
