defmodule Demo.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DemoWeb.Telemetry,
      Demo.Repo,
      {DNSCluster, query: Application.get_env(:demo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Demo.PubSub},
      {AshAuthentication.Supervisor, otp_app: :demo},
      DemoWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Demo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    DemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
