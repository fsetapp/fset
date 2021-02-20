# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :fset,
  ecto_repos: [Fset.Repo]

# Configures the endpoint
config :fset, FsetWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "bOkzilJWPhvhiu6tRBw2U0nVaDY1+TMnvzSURiQT1ydjHUrd+LktZNnqEu2h1Qqi",
  render_errors: [view: FsetWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Fset.PubSub,
  live_view: [signing_salt: "gZ0kyIRs"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
