defmodule FsetWeb.ProfileView do
  use FsetWeb, :view

  def gravatar(email, opts \\ []) do
    opts = [{:d, opts[:d] || "robohash"} | opts]
    md5_email = Base.encode16(:erlang.md5(email), case: :lower)

    "https://www.gravatar.com/avatar/"
    |> URI.parse()
    |> URI.merge(md5_email)
    |> URI.merge("?" <> URI.encode_query(opts))
    |> URI.to_string()
  end
end
