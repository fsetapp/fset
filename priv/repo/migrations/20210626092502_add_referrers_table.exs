defmodule Fset.Repo.Migrations.AddReferrersTable do
  use Ecto.Migration

  def change do
    create table(:referrers) do
      add :anchor, :uuid, null: false
      add :fmodel_id, references(:fmodels, on_delete: :restrict), null: false
      add :project_id, references(:projects, on_delete: :delete_all), null: false
    end

    create unique_index(:referrers, [:anchor])
  end
end
