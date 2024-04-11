import Config
vcap_services = System.get_env("VCAP_SERVICES")
external_app_broker = System.get_env("SERVICE_NAME")
vars = Poison.decode!(vcap_services)
external_app_list = vars[external_app_broker]
ext_service = Enum.at(external_app_list, 0)
client_id = ext_service["credentials"]["uaa"]["clientid"]
client_secret = ext_service["credentials"]["uaa"]["clientsecret"]
auth_url = ext_service["credentials"]["uaa"]["url"]
external_app_endpoint = ext_service["credentials"]["endpoints"]["ext_service-service"]

kafka = Enum.at(vars["kafka"], 0)
host_address = kafka
kafka = Enum.at(vars["kafka"], 0)
kafka_host_path = kafka["credentials"]["cluster"]["brokers"]
kafka_host = Enum.at(String.split(kafka_host_path, ","), 0)
kafka_username = kafka["credentials"]["username"]
kafka_password = kafka["credentials"]["password"]
kafka_token_url = kafka["credentials"]["urls"]["token"]
kafka_ca_cert_url = kafka["credentials"]["urls"]["ca_cert"]
kafka_topics_list = kafka["credentials"]["resources"]

user_provided = vars["user-provided"]
dynatrace = Enum.find(user_provided, fn x -> x["name"] == "dynatrace" end)
cache_key = Enum.find(user_provided, fn x -> x["name"] == "cache-key" end)
dynatrace_url = dynatrace["credentials"]["apiurl"]
dynatrace_token = dynatrace["credentials"]["apitoken"]
api_key = cache_key["credentials"]["key"]

{broker_prefix, space_name, tenant_id} =
  %{
    "external-service" =>
      {"external_app_broker_sh!b1000", "dev", "tenantID"},
    "external-service-preview" =>
      {"external_app_broker_sh!b1000", "preview", "previewtenantID"},
  }
  |> Map.get(external_app_broker)

object_scopes = [
  broker_prefix <> ".OBJECT_DELETE",
  broker_prefix <> ".OBJECT_READ",
  broker_prefix <> ".OBJECT_EDIT"
]

config :cache_api,
  client_id: client_id,
  client_secret: client_secret,
  auth_url: auth_url,
  external_app_endpoint: external_app_endpoint,
  kafka_host: kafka_host,
  kafka_username: kafka_username,
  kafka_password: kafka_password,
  kafka_token_url: kafka_token_url,
  kafka_ca_cert_url: kafka_ca_cert_url,
  kafka_topics_list: kafka_topics_list,
  api_key: api_key,
  object_scopes: object_scopes,
  external_app_space_name: space_name,
  external_app_tenant_id: tenant_id

config :opentelemetry, text_map_propagators: [:baggage, :trace_context]

config :opentelemetry,
  resource: [service: %{name: space_name <> "_cache_api", version: "1.0.0"}],
  span_processor: :batch,
  traces_exporter: :otlp,
  resource_detectors: [
    :otel_resource_app_env,
    :otel_resource_env_var,
    ExtraMetadata
  ]

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_traces_endpoint: dynatrace_url <> "/v2/otlp/v1/traces",
  otlp_traces_headers: [{"Authorization", "Api-Token " <> dynatrace_token}]
