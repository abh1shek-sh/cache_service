defmodule CacheAPI.AppRouter do
  alias CacheApi.ProcessHelper
  alias CacheApi.AuthHelper
  use Plug.Router
  require OpenTelemetry.Tracer, as: Tracer

  @moduledoc """
  The router module for the application. This module is responsible for defining the routes for the application.
  """

  plug(CacheApi.ExtractContextPlug)
  plug(CacheApi.ValidateApiKeyPlug)
  plug(:match)
  plug(:dispatch)

  get "/server/object(:object_id)/header" do
    current_span_ctx = Tracer.current_span_ctx()
    span_ctx = Tracer.start_span("object")
    Tracer.set_current_span(span_ctx)

    token = get_req_header(conn, "authorization")
    token_string = Enum.at(token, 0)
    org_id = get_req_header(conn, "organization_id")
    type = :object

    is_authorized = AuthHelper.object_scope_present?(span_ctx, token_string)

    response =
      if is_authorized do
        pid = ProcessHelper.get_cache_table_pid(span_ctx, org_id, type)
        GenServer.call(pid, {:get_data, span_ctx, object_id, token}, :infinity)
      else
        %{body: "Forbidden", status_code: 403}
      end

    Tracer.set_attributes([
      {"org_id", org_id},
      {"id", object_id},
      {"http.route", "/server/object/#{object_id}/header"},
      {"http.method", "GET"},
      {"http.status_code", response.status_code}
    ])

    CacheAPI.TracerHelper.get_trace_status(response.status_code)
    |> Tracer.set_status("")

    Tracer.end_span()
    OpenTelemetry.Span.end_span(current_span_ctx)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(response.status_code, response.body)
  end

  get "/server/templates/:template_id" do
    span_ctx = Tracer.start_span("template")
    Tracer.set_current_span(span_ctx)

    token = get_req_header(conn, "authorization")
    org_id = get_req_header(conn, "organization_id")
    type = :template
    Tracer.set_attributes([{"org_id", org_id}])
    Tracer.set_attributes([{"id", template_id}])
    Tracer.set_attributes([{"http.route", "/server/templates/#{template_id}/header"}])
    Tracer.set_attributes([{"http.method", "GET"}])

    pid = ProcessHelper.get_cache_table_pid(span_ctx, org_id, type)
    response = GenServer.call(pid, {:get_data, span_ctx, template_id, token})
    Tracer.end_span()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(response.status_code, response.body)
  end

  delete "/server/*path" do
    url_paths = conn.params["path"]
    url = Enum.join(url_paths, "/")
    _response = CacheTable.delete_element(url)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, "{}")
  end

  delete "/clear" do
    __response = CacheTable.delete()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, "{}")
  end

  get "/" do
    response = %{
      current_node: :erlang.node(),
      connected_nodes: :erlang.nodes()
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(201, Poison.encode!(response))
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
