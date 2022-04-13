defmodule Fset.Accounts.UserNotifier do
  import Phoenix.LiveView.Helpers
  import Swoosh.Email
  alias Fset.Mailer

  defp deliver(%{text: text, html: html, user: user, subject: subject}) do
    email =
      new()
      |> to({user.username, user.email})
      |> from({"FSET", "f@fset.app"})
      |> subject(subject)
      |> text_body(text)
      |> html_body(html)

    Mailer.deliver(email)
    {:ok, %{to: user.email, html: html}}
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    assigns = %{}

    text =
      ~H"""
      ==============================

      Hi <%= user.email %>,

      Thank you for choosing FSET!
      Please confirm your email address by clicking the link below.

      <%= url %>

      If you didn't create an account with us, please ignore this.

      ==============================
      """
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()

    html =
      ~H"""
        <p>Hi <%= user.email %>,</p>


        <p>Thank you for choosing FSET!</p>
        <p>Please confirm your email address by clicking the link below.</p>

        <a href={url}><%= url %></a>

        <p>If you didn't create an account with us, please ignore this.</p>
      """
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()

    deliver(%{
      user: user,
      subject: "Hello #{user.email}, please verify your FSET account",
      text: text,
      html: html
    })
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    assigns = %{}

    text =
      ~H"""
      ==============================

      Hi <%= user.email %>,

      You can reset your password by visiting the URL below:

      <%= url %>

      If you didn't request this change, please ignore this.

      ==============================
      """
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()

    html =
      ~H"""
      <p>Hi <%= user.email %>,</p>

      <p>You can reset your password by visiting the URL below:</p>

      <a href={url}><%= url %></a>

      <p>If you didn't request this change, please ignore this.</p>
      """
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()

    deliver(%{
      user: user,
      subject: "FSET Password Reset",
      text: text,
      html: html
    })
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    assigns = %{}

    text =
      ~H"""
      ==============================

      Hi <%= user.email %>,

      You can change your email by visiting the URL below:

      <%= url %>

      If you didn't request this change, please ignore this.

      ==============================
      """
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()

    html =
      ~H"""
      <p>Hi <%= user.email %>,</p>

      <p>You can change your email by visiting the URL below:</p>

      <a href={url}><%= url %></a>

      <p>If you didn't request this change, please ignore this.</p>
      """
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()

    deliver(%{
      user: user,
      subject: "FSET Email Update",
      text: text,
      html: html
    })
  end
end
