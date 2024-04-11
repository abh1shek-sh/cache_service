defmodule CacheApi.AuthHelper do
  require OpenTelemetry.Tracer, as: Tracer

  @moduledoc """
  This module is responsible for handling authentication and authorization logic.
  """

  def object_scope_present?(span_ctx, auth_header) do
    Tracer.set_current_span(span_ctx)

    Tracer.with_span "check_object_scopes", %{parent: span_ctx} do
      token = binary_part(auth_header, 7, String.length(auth_header) - 7)
      scopes = Application.get_env(:cache_api, :object_scopes)

      JOSE.JWS.peek(token)
      |> Jason.decode!()
      |> Map.get("scope")
      |> Enum.filter(fn x -> Enum.member?(scopes, x) end)
      |> length() >= 1
    end
  end
end
