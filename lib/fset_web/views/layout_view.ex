defmodule FsetWeb.LayoutView do
  use FsetWeb, :view

  def title(assigns) do
    case assigns do
      %{project: p, user: u} ->
        ~H"""
          <title><%= u.username %>/<%= p.key %>: <%= p.description %></title>
        """

      %{user: u} ->
        ~H"""
          <title><%= u.username %></title>
        """

      _ ->
        ~H"""
          <title>Fsetapp</title>
        """
    end
  end
end
