defmodule Fset.Repo.Migrations.UsersSubscriptions do
  use Ecto.Migration

  def change do
    create table(:users_subscriptions) do
      add :status, :string
      add :external_id, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :metadata, :map
    end

    create unique_index(:users_subscriptions, [:user_id])
  end
end
