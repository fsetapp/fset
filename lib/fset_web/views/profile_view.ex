defmodule FsetWeb.ProfileView do
  use FsetWeb, :view

  def gravatar(a, opts \\ [])

  def gravatar(%{avatar_url: url}, _) when not is_nil(url) do
    url
  end

  def gravatar(%{email: email}, opts) do
    opts = [{:d, opts[:d] || "robohash"} | opts]
    md5_email = Base.encode16(:erlang.md5(email), case: :lower)

    "https://www.gravatar.com/avatar/"
    |> URI.parse()
    |> URI.merge(md5_email)
    |> URI.merge("?" <> URI.encode_query(opts))
    |> URI.to_string()
  end

  def default_gravatar(opts \\ []) do
    gravatar(%{email: ""}, Keyword.merge(opts, d: "blank"))
  end
end
