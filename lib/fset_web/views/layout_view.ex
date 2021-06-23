defmodule FsetWeb.LayoutView do
  use FsetWeb, :view

  def title(assigns) do
    case assigns do
      %{project: p, user: u} ->
        ~E"""
          <title><%= u.username %>/<%= p.key %>: <%= p.description %></title>
        """

      %{user: u} ->
        ~E"""
          <title><%= u.username %></title>
        """

      _ ->
        ~E"""
          <title>Fsetapp</title>
        """
    end
  end
end
