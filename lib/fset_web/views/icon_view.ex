defmodule FsetWeb.IconView do
  use FsetWeb, :view

  def collection(opts \\ []) do
    path = ~E"""
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
    """

    svg_tag("files", path, opts)
  end

  def import(opts \\ []) do
    path = ~E"""
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
    """

    svg_tag("import", path, opts)
  end

  def export(opts \\ []) do
    path = ~E"""
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
    """

    svg_tag("export", path, opts)
  end

  def keyboard(opts \\ []) do
    path = ~E"""
    <path d="M18.6,4H1.4C0.629,4,0,4.629,0,5.4v9.2C0,15.369,0.629,16,1.399,16h17.2c0.77,0,1.4-0.631,1.4-1.4V5.4  C20,4.629,19.369,4,18.6,4z M11,6h2v2h-2V6z M14,9v2h-2V9H14z M8,6h2v2H8V6z M11,9v2H9V9H11z M5,6h2v2H5V6z M8,9v2H6V9H8z M2,6h2v2  H2V6z M5,9v2H3V9H5z M4,14H2v-2h2V14z M15,14H5v-2h10V14z M18,14h-2v-2h2V14z M15,11V9h2v2H15z M18,8h-4V6h4V8z"/>
    """

    svg_tag("hotkey", path, Keyword.merge(opts, viewbox: "0 0 20 20"))
  end

  def cut(opts \\ []) do
    path = ~E"""
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.121 14.121L19 19m-7-7l7-7m-7 7l-2.879 2.879M12 12L9.121 9.121m0 5.758a3 3 0 10-4.243 4.243 3 3 0 004.243-4.243zm0-5.758a3 3 0 10-4.243-4.243 3 3 0 004.243 4.243z" />
    """

    svg_tag("cut", path, opts)
  end

  def copy(opts \\ []) do
    path = ~E"""
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3" />
    """

    svg_tag("copy", path, opts)
  end

  def paste(opts \\ []) do
    path = ~E"""
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
    """

    svg_tag("paste", path, opts)
  end

  def clone(opts \\ []) do
    path = ~E"""
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
    """

    svg_tag("clone", path, opts)
  end

  def move_up(opts \\ []) do
    path = ~E"""
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4h13M3 8h9m-9 4h6m4 0l4-4m0 0l4 4m-4-4v12" />
    """

    svg_tag("move up", path, opts)
  end

  def move_down(opts \\ []) do
    path = ~E"""
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4h13M3 8h9m-9 4h9m5-4v12m0 0l-4-4m4 4l4-4" />
    """

    svg_tag("move down", path, opts)
  end

  def delete(opts \\ []) do
    path = ~E"""
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
    """

    svg_tag("delete", path, opts)
  end

  def add(opts \\ []) do
    path = ~E"""
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
    """

    svg_tag("add", path, opts)
  end

  defp svg_tag(title, path, opts) do
    ~E"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="<%= opts[:viewbox] || '0 0 24 24' %>" class="<%= opts[:class] || 'w-6 h-6' %>" stroke="currentColor">
      <title><%= title %></title>
      <%= path %>
    </svg>
    """
  end
end
