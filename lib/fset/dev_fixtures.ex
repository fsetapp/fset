defmodule Fset.DevFixtures do
  def projects() do
    [
      %{
        id: 1,
        name: "unclaimed_project",
        files: files(),
        entry_points: [%{id: 1, key: "model_1"}],
        current_file: 2
      }
    ]
  end

  def files() do
    [
      %{
        id: 1,
        project_id: 1,
        fmodels: [
          %{
            id: 1,
            file_id: 1,
            key: "model_1",
            sch: %{type: "record", "$anchor": Ecto.UUID.generate(), fields: %{}, order: []}
          }
        ]
      },
      %{
        id: 2,
        project_id: 1,
        fmodels: [
          %{
            id: 2,
            file_id: 2,
            key: "model_1",
            sch: %{type: "record", "$anchor": Ecto.UUID.generate(), fields: %{}, order: []}
          },
          %{
            id: 3,
            file_id: 2,
            key: "model_2",
            sch: %{type: "record", "$anchor": Ecto.UUID.generate(), fields: %{}, order: []}
          }
        ]
      }
    ]
  end
end
