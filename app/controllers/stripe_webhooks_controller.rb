class StripeWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    event = Stripe::Webhook.construct_event(
      request.raw_post,
      request.env["HTTP_STRIPE_SIGNATURE"],
      ENV.fetch("STRIPE_WEBHOOK_SECRET")
    )

    handle_event(event)

    head :ok
  rescue JSON::ParserError, Stripe::SignatureVerificationError, KeyError
    head :bad_request
  end

  private

  def handle_event(event)
    return unless %w[payment_intent.succeeded payment_intent.payment_failed payment_intent.canceled].include?(event.type)

    payment_intent = event.data.object
    order = Order.find_by(stripe_payment_id: payment_intent.id)
    return if order.blank?

    case event.type
    when "payment_intent.succeeded"
      return if order.paid?
      order.transition_to!("paid")
    when "payment_intent.payment_failed", "payment_intent.canceled"
      return if order.failed?
      order.transition_to!("failed")
    end
  end
end
