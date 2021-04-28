defmodule Fset.Repo.Migrations.AddDescriptionToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :description, :string
      add :avatar_url, :string
    end
  end
end
