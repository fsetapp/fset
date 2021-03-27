defmodule Fset.Repo.Migrations.ChangeFKIndex do
  use Ecto.Migration

  def change do
    drop unique_index(:fmodels, [:file_id])
    drop unique_index(:sch_metas, [:project_id])
    create index(:fmodels, [:file_id])
    create index(:sch_metas, [:project_id])
  end
end
