defmodule Fset.Repo.Migrations.AddUsernameToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :username, :string, null: false, default: fragment("'user_' || substring(md5(random()::text), 0, 8)")
    end
    create unique_index(:users, [:username])
  end
end
