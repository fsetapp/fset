defmodule Fset.Repo.Migrations.RemoveNonStringSchMetas do
  use Ecto.Migration

  def change do
    alter table(:sch_metas) do
      remove :rw, :string
      remove :required, :boolean
    end
    alter table(:fmodels) do
      remove :type, :string
    end
  end
end
