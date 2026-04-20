require "test_helper"
require "ostruct"

class StripeWebhooksTest < ActionDispatch::IntegrationTest
  setup do
    @province = Province.create!(
      name: "Webhook Manitoba",
      abbreviation: "WM",
      gst_rate: 0.05,
      pst_rate: 0.07,
      hst_rate: 0.0
    )

    @user = User.create!(
      email: "stripe-webhook-user@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      full_name: "Webhook User",
      address: "123 Webhook St",
      city: "Winnipeg",
      postal_code: "R3C0V8",
      province: @province
    )

    @order = @user.orders.create!(
      status: "pending",
      total_cents: 3000,
      tax_amount_cents: 360,
      shipping_address: "123 Webhook St, Winnipeg, R3C0V8",
      province_snapshot: "Manitoba",
      stripe_payment_id: "pi_match_123"
    )
  end

  test "payment_intent succeeded marks matching pending order paid" do
    with_stubbed_webhook_event(
      OpenStruct.new(
        type: "payment_intent.succeeded",
        data: OpenStruct.new(object: OpenStruct.new(id: "pi_match_123"))
      )
    ) do
      post stripe_webhook_path, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "stub" }
    end

    assert_response :success
    assert_equal "paid", @order.reload.status
  end

  test "payment_intent failed marks matching pending order failed" do
    with_stubbed_webhook_event(
      OpenStruct.new(
        type: "payment_intent.payment_failed",
        data: OpenStruct.new(object: OpenStruct.new(id: "pi_match_123"))
      )
    ) do
      post stripe_webhook_path, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "stub" }
    end

    assert_response :success
    assert_equal "failed", @order.reload.status
  end

  test "payment_intent canceled marks matching pending order failed" do
    with_stubbed_webhook_event(
      OpenStruct.new(
        type: "payment_intent.canceled",
        data: OpenStruct.new(object: OpenStruct.new(id: "pi_match_123"))
      )
    ) do
      post stripe_webhook_path, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "stub" }
    end

    assert_response :success
    assert_equal "failed", @order.reload.status
  end

  test "replayed payment_intent failed event remains idempotent" do
    @order.transition_to!("failed")

    with_stubbed_webhook_event(
      OpenStruct.new(
        type: "payment_intent.payment_failed",
        data: OpenStruct.new(object: OpenStruct.new(id: "pi_match_123"))
      )
    ) do
      post stripe_webhook_path, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "stub" }
    end

    assert_response :success
    assert_equal "failed", @order.reload.status
  end

  test "replayed payment_intent succeeded event remains idempotent" do
    @order.update!(status: "paid")

    with_stubbed_webhook_event(
      OpenStruct.new(
        type: "payment_intent.succeeded",
        data: OpenStruct.new(object: OpenStruct.new(id: "pi_match_123"))
      )
    ) do
      post stripe_webhook_path, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "stub" }
    end

    assert_response :success
    assert_equal "paid", @order.reload.status
  end

  test "payment_intent succeeded does not change shipped order" do
    @order.transition_to!("paid")
    @order.transition_to!("shipped")

    with_stubbed_webhook_event(
      OpenStruct.new(
        type: "payment_intent.succeeded",
        data: OpenStruct.new(object: OpenStruct.new(id: "pi_match_123"))
      )
    ) do
      post stripe_webhook_path, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "stub" }
    end

    assert_response :success
    assert_equal "shipped", @order.reload.status
  end

  test "payment_intent failed does not change paid order" do
    @order.transition_to!("paid")

    with_stubbed_webhook_event(
      OpenStruct.new(
        type: "payment_intent.payment_failed",
        data: OpenStruct.new(object: OpenStruct.new(id: "pi_match_123"))
      )
    ) do
      post stripe_webhook_path, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "stub" }
    end

    assert_response :success
    assert_equal "paid", @order.reload.status
  end

  test "invalid stripe signature returns bad request and does not update order" do
    with_stubbed_webhook_signature_error do
      post stripe_webhook_path, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "bad" }
    end

    assert_response :bad_request
    assert_equal "pending", @order.reload.status
  end

  test "unknown stripe payment id returns success without updating orders" do
    with_stubbed_webhook_event(
      OpenStruct.new(
        type: "payment_intent.payment_failed",
        data: OpenStruct.new(object: OpenStruct.new(id: "pi_unknown_999"))
      )
    ) do
      post stripe_webhook_path, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "stub" }
    end

    assert_response :success
    assert_equal "pending", @order.reload.status
  end

  private

  def with_stubbed_webhook_event(event)
    original_construct_event = Stripe::Webhook.method(:construct_event)
    original_webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"]
    ENV["STRIPE_WEBHOOK_SECRET"] = "whsec_test"

    Stripe::Webhook.singleton_class.send(:define_method, :construct_event) do |*_args|
      event
    end

    yield
  ensure
    Stripe::Webhook.singleton_class.send(:define_method, :construct_event, original_construct_event)
    ENV["STRIPE_WEBHOOK_SECRET"] = original_webhook_secret
  end

  def with_stubbed_webhook_signature_error
    original_construct_event = Stripe::Webhook.method(:construct_event)
    original_webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"]
    ENV["STRIPE_WEBHOOK_SECRET"] = "whsec_test"

    Stripe::Webhook.singleton_class.send(:define_method, :construct_event) do |*_args|
      raise Stripe::SignatureVerificationError.new("Invalid signature", "bad")
    end

    yield
  ensure
    Stripe::Webhook.singleton_class.send(:define_method, :construct_event, original_construct_event)
    ENV["STRIPE_WEBHOOK_SECRET"] = original_webhook_secret
  end
end
