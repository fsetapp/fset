defmodule Fset.Fmodels.SchMeta do
  use Ecto.Schema

  schema "sch_metas" do
    field :anchor, Ecto.UUID
    # shared meta
    field :title, :string
    field :description, :string
    field :rw, Ecto.Enum, values: [:rw, :r, :w]
    field :required, :boolean
    # type specific meta
    field :metadata, :map

    belongs_to :project, Fset.Projects.Project
  end
end
