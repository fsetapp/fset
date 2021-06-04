defmodule Fset.Fmodels.SchMeta do
  use Ecto.Schema

  schema "sch_metas" do
    field :anchor, Ecto.UUID
    # shared meta
    field :title, :string
    field :description, :string
    # type specific meta
    field :metadata, Ecto.Term, default: %{}

    belongs_to :project, Fset.Projects.Project
  end
end
