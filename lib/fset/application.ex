defmodule Fset.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Fset.Repo,
      # Start the Telemetry supervisor
      FsetWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Fset.PubSub},
      # Start the Endpoint (http/https)
      FsetWeb.Endpoint,
      {Finch, name: FsetHttp}
      # Start a worker by calling: Fset.Worker.start_link(arg)
      # {Fset.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Fset.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    FsetWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
