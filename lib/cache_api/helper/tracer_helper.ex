defmodule CacheAPI.TracerHelper do
  require Logger

  @moduledoc """
  Helper for logging with trace ID.
  """

  @doc """
  Logs a message with the current trace ID.
  """
  def log_with_trace_id(level, message) do
    case OpenTelemetry.Tracer.current_span_ctx() do
      :undefined ->
        Logger.log(level, message)

      span_ctx ->
        trace_id = OpenTelemetry.Span.hex_trace_id(span_ctx)
        Logger.log(level, message, trace_id: trace_id)
    end
  end

  def get_trace_status(status_code) do
    case status_code do
      200 ->
        :ok

      _ ->
        :error
    end
  end
end
