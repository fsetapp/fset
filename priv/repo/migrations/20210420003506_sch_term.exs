defmodule Fset.Repo.Migrations.SchTerm do
  use Ecto.Migration

  def change do
    alter table(:fmodels) do
      remove :sch, :json, null: false, default: Jason.encode!(%{})
      add :sch, :binary, null: false, default: ""
    end
  end
end
