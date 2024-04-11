defmodule APIHelper do
  require OpenTelemetry.Tracer, as: Tracer

  @moduledoc """
  This module is responsible for making API calls to the external system configured.
  """

  def call_api(span_ctx, url, token) do
    Tracer.set_current_span(span_ctx)

    Tracer.with_span "call_external_api", %{parent: span_ctx} do
      map_header = %{"authorization" => token, "content-type" => "application/json"}
      header_list = Enum.into(map_header, [])
      merged_header_list = :otel_propagator_text_map.inject(header_list)

      case HTTPoison.get(url, merged_header_list) do
        {:ok, %HTTPoison.Response{headers: headers, body: body, status_code: status_code}} ->
          correlation_id = get_correlation_id(headers)

          Tracer.set_attributes([
            {"http.status_code", status_code},
            {"x-correlation_id", correlation_id}
          ])

          CacheAPI.TracerHelper.log_with_trace_id(
            :info,
            "response: #{inspect(body)} status_code: #{inspect(status_code)}"
          )

          %{body: body, status_code: status_code}

        {:error, %HTTPoison.Error{reason: reason}} ->
          CacheAPI.TracerHelper.log_with_trace_id(:error, "Error occurred: #{inspect(reason)}")
          %{body: "An error occurred", status_code: 500}
      end
    end
  end

  def get_correlation_id(headers) do
    headers
    |> Enum.find_value(fn {key, value} ->
      if String.downcase(key) == "x-correlationid", do: value
    end)
  end
end
