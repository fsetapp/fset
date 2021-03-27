defmodule Fset.Repo.Migrations.CreateUuidIndex do
  use Ecto.Migration

  def change do
    rename table(:projects), :uuid, to: :anchor
    create unique_index(:projects, [:anchor])

    rename table(:files), :uuid, to: :anchor
    create unique_index(:files, [:anchor])

    rename table(:fmodels), :uuid, to: :anchor
    create unique_index(:fmodels, [:anchor])

    rename table(:sch_metas), :uuid, to: :anchor
    create unique_index(:sch_metas, [:anchor])
  end
end
