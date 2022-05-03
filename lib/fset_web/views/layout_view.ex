defmodule FsetWeb.LayoutView do
  use FsetWeb, :view

  def title(assigns) do
    case assigns do
      %{project: p, user: u} ->
        ~H"""
          <title><%= @user.username %>/<%= @project.key %>: <%= @project.description %></title>
        """

      %{user: u} ->
        ~H"""
          <title><%= @user.username %></title>
        """

      _ ->
        ~H"""
          <title>Fsetapp</title>
        """
    end
  end
end
