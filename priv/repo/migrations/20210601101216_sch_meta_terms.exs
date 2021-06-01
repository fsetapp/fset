defmodule Fset.Repo.Migrations.SchMetaTerms do
  use Ecto.Migration

  def change do
    alter table(:sch_metas) do
      remove :metadata, :map
      add :metadata, :binary
    end
  end
end
