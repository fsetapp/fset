defmodule Fset.DevFixtures do
  def projects() do
    [
      %{
        id: 1,
        key: "unclaimed_project",
        files: files(),
        order: ["file_1", "file_2"],
        entry_points: [%{id: 1, key: "model_1"}],
        current_file: 2
      }
    ]
  end

  def files() do
    [
      %{
        id: 1,
        key: "file_1",
        project_id: 1,
        order: ["model_1"],
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
        key: "file_2",
        project_id: 1,
        order: ["model_2", "model_1"],
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
