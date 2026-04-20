import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    publishableKey: String,
    clientSecret: String,
    returnUrl: String
  }

  static targets = ["mount", "errorMessage", "submitButton"]

  async connect() {
    this.clearError()
    if (!this.publishableKeyValue || !this.clientSecretValue) {
      this.setError("Missing Stripe configuration.")
      return
    }

    try {
      await this.ensureStripeLoaded()
      this.stripe = window.Stripe(this.publishableKeyValue)
      this.elements = this.stripe.elements({ clientSecret: this.clientSecretValue })
      this.paymentElement = this.elements.create("payment")
      this.paymentElement.mount(this.mountTarget)
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.disabled = false
      }
    } catch (err) {
      this.setError(err.message || "Could not load payment form.")
    }
  }

  disconnect() {
    if (this.paymentElement) {
      try {
        this.paymentElement.unmount()
      } catch (_e) {
        // ignore
      }
    }
    this.paymentElement = null
    this.elements = null
    this.stripe = null
  }

  async submit(event) {
    event.preventDefault()
    this.clearError()
    if (!this.stripe || !this.elements) {
      this.setError("Payment form is not ready yet.")
      return
    }

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
    }

    const { error } = await this.stripe.confirmPayment({
      elements: this.elements,
      confirmParams: {
        return_url: this.returnUrlValue
      }
    })

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
    }

    if (error) {
      this.setError(error.message)
    }
  }

  ensureStripeLoaded() {
    if (window.Stripe) {
      return Promise.resolve()
    }

    return new Promise((resolve, reject) => {
      const existing = document.querySelector('script[src="https://js.stripe.com/v3/"]')
      if (existing) {
        if (window.Stripe) {
          resolve()
          return
        }
        existing.addEventListener("load", () => resolve(), { once: true })
        existing.addEventListener("error", () => reject(new Error("Failed to load Stripe.js")), { once: true })
        return
      }

      const script = document.createElement("script")
      script.src = "https://js.stripe.com/v3/"
      script.async = true
      script.onload = () => resolve()
      script.onerror = () => reject(new Error("Failed to load Stripe.js"))
      document.head.appendChild(script)
    })
  }

  setError(message) {
    if (!this.hasErrorMessageTarget) {
      return
    }

    this.errorMessageTarget.textContent = message
    this.errorMessageTarget.hidden = message.length === 0
  }

  clearError() {
    if (!this.hasErrorMessageTarget) {
      return
    }

    this.errorMessageTarget.textContent = ""
    this.errorMessageTarget.hidden = true
  }
}
