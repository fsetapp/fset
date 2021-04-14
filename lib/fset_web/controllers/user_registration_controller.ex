defmodule FsetWeb.UserRegistrationController do
  use FsetWeb, :controller

  alias Fset.Accounts
  alias Fset.Accounts.User
  alias Fset.Projects
  alias FsetWeb.UserAuth

  def new(conn, _params) do
    changeset = Accounts.change_user_registration(%User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &Routes.user_confirmation_url(conn, :confirm, &1)
          )

        if project_key = user_params["project_key"],
          do: claim_project(user, project_key)

        conn
        |> put_flash(:info, "User created successfully.")
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  defp claim_project(user, project_key) do
    {:ok, project} = Projects.get_project(project_key)

    if project.users == [] do
      Projects.add_member(project_key, user.id)
    end
  end
end
