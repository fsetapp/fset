defmodule FsetWeb.UserSubscriptionController do
  use FsetWeb, :controller
  alias Fset.Payments

  plug :put_layout, {FsetWeb.LayoutView, "billing.html"}
  plug :put_view, FsetWeb.UserBillingView

  def cancel(conn, params) do
    Payments.cancel(Map.get(params, "sub_id"))
    cancelled_msg = "Subscription is cancelled, check out effective date on billing page"

    conn = put_flash(conn, :info, cancelled_msg)
    redirect(conn, to: Routes.page_path(conn, :index))
  end

  # def refund(conn, params) do
  #   Payments.refund(Map.get(params, "order_id"))
  #   redirect(conn, to: Routes.user_subscription_path(conn, :show))
  # end

  def transactions(conn, _params) do
    current_user = Payments.load_subscription(conn.assigns.current_user)

    transactions =
      if current_user.subscription do
        Payments.transactions(current_user.subscription.external_id)
      else
        []
      end

    conn = put_layout(conn, false)
    render(conn, "transactions.html", transactions: transactions)
  end

  def checkout(conn, params) do
    current_user = Payments.load_subscription(conn.assigns.current_user)

    if current_user.subscription && current_user.subscription.status == :active do
      redirect(conn, to: Routes.user_subscription_path(conn, :show))
    else
      render(conn, "checkout.html", vendor_id: 2021, product_id: params["id"])
    end
  end

  def show(conn, _params) do
    current_user = Payments.load_subscription(conn.assigns.current_user)

    if current_user.subscription do
      assigns = %{
        transactions: Payments.transactions(current_user.subscription.external_id),
        current_plan: Payments.plan(current_user.subscription),
        next_bill_date: Payments.next_payment_due(current_user.subscription),
        current_price: Payments.current_price(current_user.subscription),
        cancellation_effective_date:
          Payments.cancellation_effective_date(current_user.subscription)
      }

      assigns = Map.merge(assigns, %{subscription: current_user.subscription})
      render(conn, "show.html", assigns)
    else
      redirect(conn, to: Routes.page_path(conn, :pricing))
    end
  end
end
