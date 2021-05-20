defmodule Fset.Payments do
  alias Fset.Repo
  alias Fset.Accounts.UserSubscription
  alias Fset.Accounts

  @provider Fset.Payments.Paddle

  def transactions(sub_id, provider \\ @provider) do
    provider.transactions(sub_id)
    |> Enum.sort_by(
      fn a -> DateTime.from_iso8601(Map.get(a, "created_at")) end,
      {:desc, DateTime}
    )
  end

  def next_payment_due(sub, provider \\ @provider) do
    provider.next_payment_due(sub.metadata)
  end

  def current_price(sub, provider \\ @provider) do
    provider.current_price(sub.metadata)
  end

  def cancellation_effective_date(sub, provider \\ @provider) do
    provider.cancellation_effective_date(sub.metadata)
  end

  def plan(sub, provider \\ @provider) do
    provider.plan(sub.metadata, plans())
  end

  def plan_by_name(name) do
    Enum.find(plans(), fn plan -> plan.name == name end)
  end

  def plans() do
    [%{id: 11294, name: "FModel", price: 15}]
  end

  def cancel(sub_id, provider \\ @provider) do
    provider.cancel(sub_id)
  end

  def refund(order_id, provider \\ @provider), do: provider.refund(order_id)
  def subscription_plans(provider \\ @provider), do: provider.subscription_plans()

  def update_subscription(event, provider \\ @provider) do
    with true <- provider.verify_event(event),
         %{} = data <- provider.data(event),
         %{} = user <- Accounts.get_user_by_email(data.email) do
      %UserSubscription{}
      |> UserSubscription.changeset(%{
        metadata: data.meta,
        status: data.subscription_status,
        external_id: data.subscription_id,
        user_id: user.id
      })
      |> Repo.insert!(
        on_conflict: {:replace, [:metadata, :status, :external_id]},
        conflict_target: :user_id
      )
    else
      a -> IO.inspect(a)
    end
  end

  def delete_subscription(user, sub_id) do
    user = load_subscription(user)

    if user.subscription.external_id == sub_id do
      Repo.delete(user.subscription)
    end
  end

  def load_subscription(%Accounts.User{} = user) do
    Repo.preload(user, :subscription)
  end

  def load_subscription(%{id: id}), do: load_subscription(%Accounts.User{id: id})
end
