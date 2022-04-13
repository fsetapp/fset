defmodule Fset.Payments do
  alias Fset.Repo
  alias Fset.Accounts.UserSubscription
  alias Fset.Accounts

  @provider Fset.Payments.Paddle

  def transactions(sub_id, provider \\ @provider) do
    sort_by_created_at = fn a ->
      created_at = Map.get(a, "created_at")

      case DateTime.from_iso8601(created_at) do
        {:error, :missing_offset} ->
          {:ok, dateime, _} = DateTime.from_iso8601(created_at <> "Z")
          dateime

        blowup ->
          blowup
      end
    end

    case provider.transactions(sub_id) do
      :error ->
        []

      tx ->
        Enum.sort_by(tx, sort_by_created_at, {:desc, DateTime})
    end
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

  def is_effectively_cancelled(%{status: :cancelled} = sub) do
    if effective_date = cancellation_effective_date(sub) do
      {:ok, effective_date} = Date.from_iso8601(effective_date)

      Date.compare(Date.utc_today(), effective_date) == :gt
    else
      true
    end
  end

  def is_effectively_cancelled(_sub), do: false

  def plan(sub, provider \\ @provider) do
    provider.plan(sub.metadata, plans())
  end

  def plan_by_name(name) do
    Enum.find(plans(), fn plan -> plan.name == name end)
  end

  def plans() do
    provider_config = Application.get_env(:fset, @provider) |> Enum.into(%{})
    provider_config.plans
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
      a ->
        # subscription status out of sync
        IO.inspect(a)
    end
  end

  def out_of_sync_check(sub, provider \\ @provider)
  def out_of_sync_check(nil, _), do: :nothing

  def out_of_sync_check(sub, provider) do
    data = provider.data(sub.metadata)

    if data.subscription_status != sub.status do
      subscribers = provider.subscribers(%{subscription_id: sub.external_id})

      fresh_sub =
        Enum.find(subscribers, fn subscriber ->
          "#{subscriber["subscription_id"]}" == sub.external_id
        end)

      if fresh_sub do
        %UserSubscription{}
        |> UserSubscription.changeset(%{
          status: provider.status(%{"status" => fresh_sub["state"]}),
          user_id: sub.user_id
        })
        |> Repo.insert!(
          on_conflict: {:replace, [:status]},
          conflict_target: :user_id
        )
      end
    end
  end

  # We currently do not delete subscription since we sometimes need it for a ground
  # to check againts.
  def delete_subscription(user, sub_id) do
    user = load_subscription(user)

    if user.subscription.external_id == "#{sub_id}" do
      Repo.delete(user.subscription)
    end
  end

  def load_subscription(%Accounts.User{} = user) do
    Repo.preload(user, :subscription)
  end

  def load_subscription(%{id: id}), do: load_subscription(%Accounts.User{id: id})
end
