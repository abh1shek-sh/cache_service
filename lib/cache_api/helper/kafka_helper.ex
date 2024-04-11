defmodule KafkaHelper do
  @topics_map %{
    :object => "com.v1.object.int.",
    :template => "com.v1.template.int."
  }

  @moduledoc """
  Helper module for Kafka operations.
  """

  def get_token() do
    client_id = Application.get_env(:cache_api, :kafka_username)
    client_secret = Application.get_env(:cache_api, :kafka_password)
    url = Application.get_env(:cache_api, :kafka_token_url)

    req_body = URI.encode_query(%{"grant_type" => "client_credentials"})

    credentials = "#{client_id}:#{client_secret}" |> Base.encode64()
    token = "Basic #{credentials}"

    map_header = %{
      "authorization" => token,
      "content-type" => "application/x-www-form-urlencoded"
    }

    resp = HTTPoison.post!(url, req_body, map_header)
    Poison.decode!(resp.body)["access_token"]
  end

  def get_der_cert() do
    url = Application.get_env(:cache_api, :kafka_ca_cert_url)
    resp = HTTPoison.get!(url)
    cert = resp.body

    ## Decode the PEM certifciate and convert it into DER
    pem_entries = :public_key.pem_decode(cert)
    for {:Certificate, cert, :not_encrypted} <- pem_entries, do: cert
  end

  def get_topic(topic_name) do
    space_name = Application.get_env(:cache_api, :external_app_space_name)
    tenant_id = Application.get_env(:cache_api, :external_app_tenant_id)
    %{^topic_name => topic} = @topics_map
    topic <> space_name <> "." <> tenant_id
  end
end
