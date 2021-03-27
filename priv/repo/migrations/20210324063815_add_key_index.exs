defmodule Fset.Repo.Migrations.AddKeyIndex do
  use Ecto.Migration

  def change do
    create unique_index(:projects, [:key])
    create unique_index(:files, [:key, :project_id])
    create unique_index(:fmodels, [:key, :file_id])
  end
end
