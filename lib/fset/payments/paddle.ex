defmodule Fset.Payments.Paddle do
  def data(event) do
    %{
      subscription_id: Map.fetch!(event, "subscription_id"),
      subscription_status: status(event),
      email: Map.fetch!(event, "email"),
      meta: Map.delete(event, "p_signature")
    }
  end

  def plan(event, plans) do
    subscription_plan_id = Map.fetch!(event, "subscription_plan_id")
    Enum.find(plans, fn plan -> "#{plan.id}" == subscription_plan_id end)
  end

  def next_payment_due(event) do
    Map.get(event, "next_bill_date")
  end

  def current_price(event) do
    Map.get(event, "unit_price") || Map.get(event, "new_unit_price")
  end

  def cancellation_effective_date(event) do
    Map.get(event, "cancellation_effective_date")
  end

  def status(event) do
    case Map.fetch!(event, "status") do
      "active" -> :active
      "deleted" -> :cancelled
      _ -> :unknown
    end
  end

  def cancel(sub_id) do
    request(:post, "/2.0/subscription/users_cancel", %{subscription_id: sub_id})
  end

  def refund(order_id) do
    request(:post, "/2.0/payment/refund", %{order_id: order_id})
  end

  def transactions(sub_id) do
    request(:get, "/2.0/subscription/#{sub_id}/transactions")
  end

  def subscription_plans() do
    request(:get, "/2.0/subscription/plans")
  end

  def subscribers(opts \\ %{}) do
    request(:post, "/2.0/subscription/users", opts)
  end

  defp request(method, path, params \\ %{}, retry \\ 3)
  defp request(_method, _path, _params, 0), do: :error

  defp request(method, path, params, retry) do
    headers = [{"content-type", "application/json"}]

    paddle_config = Application.get_env(:fset, __MODULE__) |> Enum.into(%{})
    auth_body = Map.take(paddle_config, [:vendor_auth_code, :vendor_id])
    body = Map.merge(auth_body, params)

    url = Finch.build(method, api_url(path), headers, Jason.encode!(body))

    with {:ok, result} <- Finch.request(url, FsetHttp),
         {:ok, %{"response" => resp}} <- Jason.decode(result.body) do
      resp
    else
      err ->
        IO.inspect(err, label: "Paddle.request")
        request(method, path, params, retry - 1)
    end
  end

  defp api_url(path) do
    paddle_config = Application.get_env(:fset, __MODULE__) |> Enum.into(%{})

    paddle_config.api_url
    |> URI.parse()
    |> URI.merge("/api" <> path)
    |> URI.to_string()
  end

  def verify_event(event) do
    p_signature = Map.get(event, "p_signature")
    signature = Base.decode64!(p_signature)
    event = Map.delete(event, "p_signature")
    event = Enum.sort_by(event, fn {k, _} -> k end)
    message = PhpSerializer.serialize(event)

    if public_key = System.get_env("PADDLE_PUBLIC_KEY") do
      [rsa_entry] = :public_key.pem_decode(public_key)
      public_key = :public_key.pem_entry_decode(rsa_entry)

      :public_key.verify(message, :sha, signature, public_key)
    end
  end
end
