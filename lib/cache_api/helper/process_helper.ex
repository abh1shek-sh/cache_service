defmodule CacheApi.ProcessHelper do
  require OpenTelemetry.Tracer, as: Tracer

  @moduledoc """
  This module is responsible for creating and managing the cache table process for each organization and type.
  """

  def get_cache_table_pid(span_ctx, org_id, type) do
    Tracer.with_span "get_table_pid", %{parent: span_ctx} do
      name = {org_id, type}

      case Registry.lookup(CacheRegistry, name) do
        [] ->
          Tracer.with_span "create cache genserver for org" do
            CacheAPI.TracerHelper.log_with_trace_id(
              :info,
              "creating new process for #{org_id} and #{type}"
            )

            {:ok, new_pid} = CacheTable.start_link(org_id: org_id, type: type)
            new_pid
          end

        [{existing_pid, _}] ->
          existing_pid
      end
    end
  end
end
