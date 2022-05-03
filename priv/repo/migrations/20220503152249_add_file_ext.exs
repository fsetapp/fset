defmodule Fset.Repo.Migrations.AddFileExt do
  use Ecto.Migration

  def change do
    alter table(:files) do
      # KEEP_EXT = 0
      add :t, :integer, null: false, default: 0
    end
  end
end
