defmodule FsetWeb.APIPaymentController do
  use FsetWeb, :controller
  alias Fset.Payments

  def notify(conn, params) do
    case params["alert_name"] do
      "subscription_" <> _ -> Payments.update_subscription(params)
      _ -> :nothing
    end

    send_resp(conn, 200, "")
  end
end
