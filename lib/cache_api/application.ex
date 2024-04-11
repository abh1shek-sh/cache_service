defmodule CacheAPI.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    port = elem(Integer.parse(System.get_env("PORT")), 0)
    # port = 4001

    {:ok, _pid} = :pg.start_link()
    # List all child processes to be supervised
    children = [
      {ObjectConsumer, []},
      {Registry, keys: :unique, name: CacheRegistry},
      {Plug.Cowboy,
       scheme: :http,
       plug: CacheAPI.AppRouter,
       options: [
         port: port,
         protocol_options: [
           max_header_value_length: 8096,
           max_keepalive: 5_000_000
         ]
       ]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CacheAPI.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
