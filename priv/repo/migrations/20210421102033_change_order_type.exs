defmodule Fset.Repo.Migrations.ChangeOrderType do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      remove :order
    end
    alter table(:files) do
      remove :order
      add :order, :integer
    end
    alter table(:fmodels) do
      add :order, :integer
    end
  end
end
