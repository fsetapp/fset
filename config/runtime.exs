import Config

if config_env() == :prod do
  config :fset, Fset.Mailer,
    adapter: Swoosh.Adapters.Mailgun,
    api_key: System.get_env("MAILER_API_KEY"),
    domain: System.get_env("MAILER_DOMAIN")

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  hostname =
    System.get_env("FSET_HOST_URL") ||
      raise "FSET_HOST_URL not available"

  config :fset, FsetWeb.Endpoint,
    server: true,
    url: [host: hostname, port: 80],
    http: [
      port: String.to_integer(System.get_env("PORT") || "4000"),
      # IMPORTANT: support IPv6 addresses
      transport_options: [socket_opts: [:inet6]]
    ],
    secret_key_base: secret_key_base

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  config :fset, Fset.Repo,
    url: database_url,
    ssl: true,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    prepare: :unnamed

  config :fset, Fset.Payments.Paddle,
    vendor_auth_code: System.get_env("VENDOR_AUTH_CODE"),
    vendor_id: System.get_env("VENDOR_ID"),
    api_url: "https://vendors.paddle.com",
    plans: [%{id: 667_595, name: "FModel", price: 15}]
end
