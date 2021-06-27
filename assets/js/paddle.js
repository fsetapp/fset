import "phoenix_html"

customElements.define("paddle-checkout", class extends HTMLElement {
  connectedCallback() {
    Paddle.Environment.set("sandbox")
    Paddle.Setup({ vendor: parseInt(this.dataset.vendorId), eventCallback: this.checkoutCallback.bind(this) })
    Paddle.Checkout.open({
      method: "inline",
      product: this.dataset.productId,
      email: this.dataset.email,
      allowQuantity: false,
      disableLogout: true,
      frameTarget: "checkout-container",
      frameInitialHeight: 0,
      frameStyle: `
        display: flex;
        align-items: center;
        width:100%;
        min-width:312px;
        border: none;
      `
    })
  }
  checkoutCallback(e) {
    const pricing = (data) => {
      const subtotal = data.recurring_prices.customer.total - data.recurring_prices.customer.total_tax
      const saleTaxPercent = data.recurring_prices.customer.total_tax / subtotal * 100

      this.querySelector("[id='pricing']").outerHTML = `
        <li id="pricing">
          <dl class="text-gray-500 mt-1 mb-2 flex justify-between">
            <dt>Subscription</dt>
            <dd class="text-sm">${data.recurring_prices.customer.currency} / ${data.recurring_prices.interval.type}</dd>
          </dl>
          <dl class="flex justify-between">
            <dt>Subtotal</dt>
            <dd class="text-lg">${subtotal}</dd>
          </dl>
          <dl class="flex justify-between">
            <dt>Tax <span class="text-xs">(${saleTaxPercent.toPrecision(2)}%)</span></dt>
            <dd class="text-lg">${data.recurring_prices.customer.total_tax}</dd>
          </dl>
          <dl class="flex justify-between">
            <dt>Total</dt>
            <dd class="text-lg">${data.recurring_prices.customer.total}</dd>
          </dl>
        </li>
      `
    }
    switch (e.event) {
      case "Checkout.Complete":
        this.querySelector("[id='purchased']").classList.remove("hidden")
        break
      default:
        pricing(e.eventData.checkout)
    }
  }
})
