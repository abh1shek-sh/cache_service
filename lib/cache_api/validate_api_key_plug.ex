defmodule CacheApi.ValidateApiKeyPlug do
  @behaviour Plug
  import Plug.Conn
  require Logger
  require OpenTelemetry.Tracer, as: Tracer

  @moduledoc """
  module responsible for validating the API key in the request header.
  """

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    span_ctx = Tracer.start_span("validate_api_key")
    Tracer.set_current_span(span_ctx)
    api_key = Enum.at(get_req_header(conn, "api-key"), 0)
    valid_api_key = Application.get_env(:cache_api, :api_key)
    is_key_valid = api_key == valid_api_key
    Tracer.set_attribute("is_key_valid", is_key_valid)

    if valid_api_key && is_key_valid do
      conn
    else
      CacheAPI.TracerHelper.log_with_trace_id(
        :error,
        """
        Unauthorzed request with following headers:
        host: #{conn.host},
        api_key: #{api_key},
        authorization: #{Enum.at(get_req_header(conn, "authorization"), 0)},
        organization_id: #{Enum.at(get_req_header(conn, "organiztion_id"), 0)}
        """
      )

      Tracer.set_status(:error, "Unauthorized")
      Tracer.end_span()
      send_resp(conn, 401, "Unauthorized") |> halt()
    end
  end
end
