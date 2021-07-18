defmodule Fset.Repo.Migrations.PrivateProject do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :visibility, :string, null: false, default: "private"
      add :pin, :boolean, null: false, default: false
    end
  end
end
