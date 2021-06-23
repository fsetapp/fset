defmodule Fset.Repo.Migrations.UsernameCitext do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    alter table(:users) do
      modify :username, :citext, from: :string, null: false, default: fragment("'user_' || substring(md5(random()::text), 0, 8)")
    end
  end
end
