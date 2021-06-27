defmodule Fset.Fmodels.Referrer do
  use Ecto.Schema

  @moduledoc """
  This is a referential "integrity" storage, served as a cache of integrity check
  at "some" point. We check ref-integrity in several places such as on client-side,
  and critically at output compilation process.

  NOT a source of truth of referential "data" storage.
  """

  schema "referrers" do
    field :anchor, Ecto.UUID
    belongs_to :fmodel, Fset.Fmodels.Fmodel
    belongs_to :project, Fset.Projects.Project
  end
end
