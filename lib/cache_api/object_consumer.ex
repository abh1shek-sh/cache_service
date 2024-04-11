defmodule ObjectConsumer do
  use Broadway
  require OpenTelemetry.Tracer, as: Tracer

  @moduledoc """
  module for consuming the messages from the kafka topic and invalidating the cache.
  """

  @update_types [
    "object.update",
    "object.publish",
    "object.revision",
    "object.delete"
  ]

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module:
          {BroadwayKafka.Producer,
           [
             hosts: Application.get_env(:cache_api, :kafka_host),
             group_id: "dvh-" <> Application.get_env(:cache_api, :external_app_space_name),
             topics: [KafkaHelper.get_topic(:object)],
             client_config: [
               sasl:
                 {:plain, Application.get_env(:cache_api, :kafka_username),
                  KafkaHelper.get_token()},
               ssl: [
                 verify_type: :verify_peer,
                 cacerts: KafkaHelper.get_der_cert(),
                 ## For OTP 26
                 versions: [:"tlsv1.2"]
               ]
             ]
           ]},
        concurrency: 1
      ],
      processors: [
        default: [
          concurrency: 10
        ]
      ],
      batchers: [
        default: [
          batch_size: 100,
          batch_timeout: 200,
          concurrency: 10
        ]
      ]
    )
  end

  @impl true
  def handle_message(_, message, _) do
    data = Poison.decode!(message.data)

    case(data) do
      %{"type" => type} when type in @update_types ->
        CacheAPI.TracerHelper.log_with_trace_id(:info, "message: #{inspect(data)}")
        object_id = data["objectid"]
        span_ctx = Tracer.start_span("kafka.object." <> object_id)
        Tracer.set_current_span(span_ctx)
        Tracer.set_attributes([{"id", object_id}, {"type", data["type"]}])

        :pg.get_members(:equipment_header)
        |> Enum.each(fn pid ->
          GenServer.cast(pid, {:invalidate_cache, span_ctx, object_id})
        end)

        Tracer.end_span()
    end

    message
  rescue
    _ -> message
  end

  @impl true
  def handle_batch(_, messages, _, _) do
    messages
  end
end
