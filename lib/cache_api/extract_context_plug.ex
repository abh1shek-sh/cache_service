defmodule CacheApi.ExtractContextPlug do
  @behaviour Plug
  require Logger

  @moduledoc """
   Module responsible for extracting the OpenTelmerty context from the request headers to propagate the trace.
  """

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    context = :otel_propagator_text_map.extract_to(:otel_ctx.new(), conn.req_headers)
    OpenTelemetry.Ctx.attach(context)
    conn
  end
end
