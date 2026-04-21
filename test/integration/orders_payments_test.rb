require "test_helper"
require "ostruct"

class OrdersPaymentsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @province = Province.create!(
      name: "Manitoba Payment",
      abbreviation: "MP",
      gst_rate: 0.05,
      pst_rate: 0.07,
      hst_rate: 0.0
    )

    @user = User.create!(
      email: "orders-payments@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      full_name: "Orders Payments User",
      address: "777 Test St",
      city: "Winnipeg",
      postal_code: "R3C0V8",
      province: @province
    )

    @order = @user.orders.create!(
      status: "pending",
      total_cents: 1500,
      tax_amount_cents: 180,
      shipping_address: "777 Test St, Winnipeg, R3C0V8",
      province_snapshot: "Manitoba"
    )
  end

  test "signed in user can start payment for pending order" do
    sign_in @user

    with_stubbed_checkout_session_create(OpenStruct.new(id: "cs_test_123", url: "https://checkout.stripe.com/c/pay/cs_test_123")) do
      post start_payment_order_path(@order)
    end

    assert_redirected_to "https://checkout.stripe.com/c/pay/cs_test_123"
    @order.reload
    assert_equal "cs_test_123", @order.stripe_payment_id
  end

  test "signed in user can retry payment for failed order" do
    sign_in @user
    @order.update!(status: "failed", stripe_payment_id: "cs_old_123")

    with_stubbed_checkout_session_create(OpenStruct.new(id: "cs_test_123", url: "https://checkout.stripe.com/c/pay/cs_test_123")) do
      post start_payment_order_path(@order)
    end

    assert_redirected_to "https://checkout.stripe.com/c/pay/cs_test_123"
    @order.reload
    assert_equal "failed", @order.status
    assert_equal "cs_test_123", @order.stripe_payment_id
  end

  test "payment success marks order paid when stripe confirms" do
    sign_in @user
    @order.update!(status: "failed", stripe_payment_id: "cs_test_123")

    fake_session = OpenStruct.new(
      payment_status: "paid",
      metadata: OpenStruct.new(order_id: @order.id.to_s),
      payment_intent: OpenStruct.new(id: "pi_test_123"),
      customer: "cus_test_123"
    )

    with_stubbed_checkout_session_retrieve(fake_session) do
      get payment_success_order_path(@order, session_id: "cs_test_123")
    end

    assert_redirected_to order_path(@order)
    @order.reload
    assert_equal "paid", @order.status
    assert_equal "pi_test_123", @order.stripe_payment_id
    assert_equal "cus_test_123", @order.stripe_customer_id
  end

  test "payment success is rejected when stripe order id does not match" do
    sign_in @user
    @order.update!(stripe_payment_id: "cs_test_123")

    fake_session = OpenStruct.new(
      payment_status: "paid",
      metadata: OpenStruct.new(order_id: "999999"),
      payment_intent: OpenStruct.new(id: "pi_test_123"),
      customer: "cus_test_123"
    )

    with_stubbed_checkout_session_retrieve(fake_session) do
      get payment_success_order_path(@order, session_id: "cs_test_123")
    end

    assert_redirected_to order_path(@order)
    follow_redirect!
    assert_includes response.body, "Stripe confirmation did not match this order."
  end

  test "payment success is rejected when session id is missing" do
    sign_in @user

    get payment_success_order_path(@order)

    assert_redirected_to order_path(@order)
    follow_redirect!
    assert_includes response.body, "Missing Stripe session confirmation."
  end

  test "signed in user cannot start payment for non-pending order" do
    sign_in @user
    @order.update!(status: "paid", stripe_payment_id: "cs_paid_123")

    post start_payment_order_path(@order)

    assert_redirected_to order_path(@order)
    follow_redirect!
    assert_includes response.body, "Only pending or failed orders can start payment."
  end

  test "signed in user can cancel pending order and cannot restart payment after" do
    sign_in @user
    @order.update!(status: "pending", stripe_payment_id: "cs_test_123")

    post cancel_order_order_path(@order)

    assert_redirected_to order_path(@order)
    @order.reload
    assert_equal "cancelled", @order.status

    post start_payment_order_path(@order)
    assert_redirected_to order_path(@order)
    follow_redirect!
    assert_includes response.body, "Only pending or failed orders can start payment."
  end

  test "payment cancel marks pending order failed for retry" do
    sign_in @user
    @order.update!(status: "pending")

    get payment_cancel_order_path(@order)

    assert_redirected_to order_path(@order)
    @order.reload
    assert_equal "failed", @order.status
  end

  private

  def with_stubbed_checkout_session_create(fake_session)
    original_create = Stripe::Checkout::Session.method(:create)

    Stripe::Checkout::Session.singleton_class.send(:define_method, :create) do |*_args|
      fake_session
    end

    yield
  ensure
    Stripe::Checkout::Session.singleton_class.send(:define_method, :create, original_create)
  end

  def with_stubbed_checkout_session_retrieve(fake_session)
    original_retrieve = Stripe::Checkout::Session.method(:retrieve)

    Stripe::Checkout::Session.singleton_class.send(:define_method, :retrieve) do |*_args|
      fake_session
    end

    yield
  ensure
    Stripe::Checkout::Session.singleton_class.send(:define_method, :retrieve, original_retrieve)
  end
end
