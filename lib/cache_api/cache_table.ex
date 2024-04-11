defmodule CacheTable do
  use GenServer
  require OpenTelemetry.Tracer, as: Tracer

  @moduledoc """
  module for caching the data fetched from the configured external service and then serving the data from the cache.
  """

  @external_app_suffix "ext_service/services/api/v1/"
  @urls [object: "object(<%=id%>)/header", template: "templates/<%=id%>"]

  def start_link(opts) do
    name = {opts[:org_id], opts[:type]}

    {:ok, pid} =
      GenServer.start_link(__MODULE__, opts, name: {:via, Registry, {CacheRegistry, name}})

    :pg.join(opts[:type], pid)
    {:ok, pid}
  end

  @impl true
  def init(opts) do
    tid = :ets.new(:set, [:public, read_concurrency: true, write_concurrency: true])
    Process.put(:table, tid)
    Process.put(:type, opts[:type])
    Process.put(:org_id, opts[:org_id])
    {:ok, nil}
  end

  @impl true
  def handle_call({:get_data, span_ctx, id, token}, from, state) do
    table = Process.get(:table)
    type = Process.get(:type)
    spawn(CacheTable, :get_data, [span_ctx, id, token, type, table, from])
    {:noreply, state}
  end

  def get_data(span_ctx, id, token, type, table, from) do
    Tracer.set_current_span(span_ctx)

    Tracer.with_span "get_data_from_cache", %{parent: span_ctx} do
      IO.puts(id)
      body = :ets.lookup_element(table, id, 2)
      response = %{body: body, status_code: 200}
      GenServer.reply(from, response)
    end
  rescue
    _ ->
      call_api(span_ctx, id, token, type, table, from)
  end

  def lookup(element) do
    :ets.lookup_element(:table, element, 2)
  end

  def delete_element(element) do
    :ets.delete(:table, element)
  end

  def delete() do
    :ets.delete_all_objects(:table)
  end

  @impl true
  def handle_cast({:invalidate_cache, span_ctx, key}, state) do
    Tracer.set_current_span(span_ctx)

    Tracer.with_span "invalidate_cache", %{parent: span_ctx} do
      CacheAPI.TracerHelper.log_with_trace_id(:info, "invalidating cache for #{key}")
      Tracer.set_attributes([{"org_id", Process.get(:org_id)}])
      table_name = Process.get(:table)
      :ets.delete(table_name, key)
      {:noreply, state}
    end
  end

  def call_api(span_ctx, id, token, type, table, from) do
    external_app_endpoint = Application.get_env(:cache_api, :external_app_endpoint)
    url = external_app_endpoint <> @external_app_suffix <> EEx.eval_string(@urls[type], id: id)

    CacheAPI.TracerHelper.log_with_trace_id(
      :info,
      "making API call to ext_service to fetch the data"
    )

    response = APIHelper.call_api(span_ctx, url, token)

    if response.status_code == 200 do
      Tracer.with_span "ets_insert", %{parent: span_ctx} do
        CacheAPI.TracerHelper.log_with_trace_id(:info, "updating cache")
        :ets.insert(table, {id, response.body})
      end
    end

    GenServer.reply(from, response)
  end
end
