defmodule Fset.Accounts.UserSubscription do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users_subscriptions" do
    field :external_id, :string
    field :status, Ecto.Enum, values: [:active, :cancelled, :unknown]
    field :metadata, :map
    belongs_to :user, Fset.Accounts.User
  end

  def changeset(subscription, attrs \\ %{}) do
    subscription
    |> cast(attrs, [:status, :metadata, :external_id, :user_id])
    |> foreign_key_constraint(:user_id)
  end
end
