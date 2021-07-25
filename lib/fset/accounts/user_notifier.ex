defmodule Fset.Accounts.UserNotifier do
  import Phoenix.HTML
  import Swoosh.Email
  alias Fset.Mailer

  defp new_email(text, html, user, subject) do
    new()
    |> to({user.username, user.email})
    |> from({"FSET", "f@fset.app"})
    |> subject(subject)
    |> text_body(text)
    |> html_body(html)
  end

  # defp deliver(to, body) do
  #   require Logger
  #   Logger.debug(body)
  #   {:ok, %{to: to, body: body}}
  # end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    text =
      ~E"""
      ==============================

      Hi <%= user.email %>,

      Thank you for choosing FSET!
      Please confirm your email address by clicking the link below.

      <%= url %>

      If you didn't create an account with us, please ignore this.

      ==============================
      """
      |> safe_to_string()

    html =
      ~E"""
        <p>Hi <%= user.email %>,</p>


        <p>Thank you for choosing FSET!</p>
        <p>Please confirm your email address by clicking the link below.</p>

        <a href=<%= url %>><%= url %></a>

        <p>If you didn't create an account with us, please ignore this.</p>
      """
      |> safe_to_string()

    new_email(text, html, user, "Hello #{user.email}, please verify your FSET account")
    |> Mailer.deliver()
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    text =
      ~E"""
      ==============================

      Hi <%= user.email %>,

      You can reset your password by visiting the URL below:

      <%= url %>

      If you didn't request this change, please ignore this.

      ==============================
      """
      |> safe_to_string()

    html =
      ~E"""
      <p>Hi <%= user.email %>,</p>

      <p>You can reset your password by visiting the URL below:</p>

      <a href=<%= url %>><%= url %></a>

      <p>If you didn't request this change, please ignore this.</p>
      """
      |> safe_to_string()

    new_email(text, html, user, "FSET Password Reset")
    |> Mailer.deliver()
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    text =
      ~E"""
      ==============================

      Hi <%= user.email %>,

      You can change your email by visiting the URL below:

      <%= url %>

      If you didn't request this change, please ignore this.

      ==============================
      """
      |> safe_to_string()

    html =
      ~E"""
      <p>Hi <%= user.email %>,</p>

      <p>You can change your email by visiting the URL below:</p>

      <a href=<%= url %>><%= url %></a>

      <p>If you didn't request this change, please ignore this.</p>
      """
      |> safe_to_string()

    new_email(text, html, user, "FSET Email Update")
    |> Mailer.deliver()
  end
end
