defmodule Fset.Repo.Migrations.AddProjectsTable do
  use Ecto.Migration

  def change do
    create table(:projects) do
      add :uuid, :uuid, null: false
      add :key, :string, null: false
      add :order, {:array, :string}, default: []
      add :description, :string
      timestamps()
    end

    create table(:files) do
      add :uuid, :uuid, null: false
      add :key, :string, null: false
      add :order, {:array, :string}, default: []
      timestamps()

      add :project_id, references(:projects, on_delete: :delete_all), null: false
    end

    create table(:fmodels) do
      add :uuid, :uuid, null: false
      add :type, :string, null: false
      add :key, :string, null: false
      add :sch, :json, null: false
      add :order, {:array, :string}, default: []
      add :is_entry, :boolean, null: false, default: false

      add :file_id, references(:files, on_delete: :delete_all), null: false
    end
    create unique_index(:fmodels, [:file_id])

    create table(:sch_metas) do
      add :uuid, :uuid, null: false
      add :title, :text
      add :description, :text
      add :project_id, references(:projects, on_delete: :delete_all), null: false
    end
    create index(:sch_metas, [:uuid])
    create unique_index(:sch_metas, [:project_id])

    create table(:projects_users) do
      add :project_id, references(:projects), null: false
      add :user_id, references(:users), null: false
      add :role, :string, null: false
    end
    create unique_index(:projects_users, [:project_id, :user_id])
  end
end
