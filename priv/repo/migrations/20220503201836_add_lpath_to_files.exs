defmodule Fset.Repo.Migrations.AddLpathToFiles do
  use Ecto.Migration

  def change do
    alter table(:files) do
      add :lpath, :binary, null: false, default: "[]"
    end
  end
end
