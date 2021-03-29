defmodule Fset.Repo.Migrations.SchMetaMetadata do
  use Ecto.Migration

  def change do
    alter table(:sch_metas) do
      add :rw, :string
      add :required, :boolean
      add :metadata, :map
    end
  end
end
