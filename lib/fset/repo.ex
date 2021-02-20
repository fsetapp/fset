defmodule Fset.Repo do
  use Ecto.Repo,
    otp_app: :fset,
    adapter: Ecto.Adapters.Postgres
end
