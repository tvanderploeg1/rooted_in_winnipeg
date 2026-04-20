require "test_helper"
require "ostruct"

class OrdersAccessTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @province = Province.create!(
      name: "Manitoba Test",
      abbreviation: "MT",
      gst_rate: 0.05,
      pst_rate: 0.07,
      hst_rate: 0.0
    )

    @user_one = User.create!(
      email: "orders-access-one@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      full_name: "Orders User One",
      address: "123 Test St",
      city: "Winnipeg",
      postal_code: "R3C0V8",
      province: @province
    )

    @user_two = User.create!(
      email: "orders-access-two@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      full_name: "Orders User Two",
      address: "456 Test Ave",
      city: "Winnipeg",
      postal_code: "R3C0V8",
      province: @province
    )

    @order_one = @user_one.orders.create!(
      status: "pending",
      total_cents: 1500,
      tax_amount_cents: 180,
      shipping_address: "123 Test St, Winnipeg, R3C0V8",
      province_snapshot: "Manitoba"
    )

    @order_two = @user_two.orders.create!(
      status: "paid",
      total_cents: 2200,
      tax_amount_cents: 264,
      shipping_address: "456 Test Ave, Winnipeg, R3C0V8",
      province_snapshot: "Manitoba"
    )
  end

  test "guest is redirected from orders index" do
    get orders_path

    assert_redirected_to new_user_session_path
  end

  test "signed in user sees only their own orders in index" do
    sign_in @user_one

    get orders_path

    assert_response :success
    assert_includes response.body, order_path(@order_one)
    assert_not_includes response.body, order_path(@order_two)
  end

  test "signed in user can view their own order" do
    sign_in @user_one

    get order_path(@order_one)

    assert_response :success
    assert_match "Order ##{@order_one.id}", response.body
  end

  test "signed in user cannot view another user's order" do
    sign_in @user_one

    get order_path(@order_two)

    assert_redirected_to orders_path
    follow_redirect!
    assert_includes response.body, "Order not found."
  end

  test "guest is redirected from start payment" do
    post start_payment_order_path(@order_one)

    assert_redirected_to new_user_session_path
  end

  test "signed in user can start payment for their pending order" do
    sign_in @user_one

    with_stubbed_payment_intent_create do
      post start_payment_order_path(@order_one)
    end

    assert_redirected_to payment_order_path(@order_one)
    @order_one.reload
    assert_equal "pi_test_123", @order_one.stripe_payment_id
    assert_equal "cus_test_123", @order_one.stripe_customer_id
  end

  test "guest is redirected from payment page" do
    get payment_order_path(@order_one)

    assert_redirected_to new_user_session_path
  end

  test "signed in user can view payment page for their pending order with started payment" do
    sign_in @user_one
    @order_one.update!(stripe_payment_id: "pi_test_123")

    with_stubbed_payment_intent_retrieve do
      get payment_order_path(@order_one)
    end

    assert_response :success
    assert_includes response.body, "Payment for Order ##{@order_one.id}"
    assert_includes response.body, "data-controller=\"stripe-payment\""
    assert_includes response.body, "Pay now"
  end

  test "signed in user cannot view payment page for non pending order" do
    sign_in @user_two
    @order_two.update!(stripe_payment_id: "pi_paid_123")

    get payment_order_path(@order_two)

    assert_redirected_to order_path(@order_two)
    follow_redirect!
    assert_includes response.body, "Payment page is only available for pending orders."
  end

  test "signed in user cannot view payment page before payment is started" do
    sign_in @user_one

    get payment_order_path(@order_one)

    assert_redirected_to order_path(@order_one)
    follow_redirect!
    assert_includes response.body, "Start payment first before opening payment details."
  end

  test "signed in user cannot view another users payment page" do
    sign_in @user_one

    get payment_order_path(@order_two)

    assert_redirected_to orders_path
    follow_redirect!
    assert_includes response.body, "Order not found."
  end

  test "signed in user cannot start payment for non-pending order" do
    sign_in @user_two

    post start_payment_order_path(@order_two)

    assert_redirected_to order_path(@order_two)
    follow_redirect!
    assert_includes response.body, "Only pending orders can start payment."
  end

  test "signed in user cannot start payment for another users order" do
    sign_in @user_one

    post start_payment_order_path(@order_two)

    assert_redirected_to orders_path
    follow_redirect!
    assert_includes response.body, "Order not found."
  end

  private

  def with_stubbed_payment_intent_create
    original_create = Stripe::PaymentIntent.method(:create)

    Stripe::PaymentIntent.singleton_class.send(:define_method, :create) do |*_args|
      OpenStruct.new(id: "pi_test_123", customer: "cus_test_123")
    end

    yield
  ensure
    Stripe::PaymentIntent.singleton_class.send(:define_method, :create, original_create)
  end

  def with_stubbed_payment_intent_retrieve
    original_retrieve = Stripe::PaymentIntent.method(:retrieve)

    Stripe::PaymentIntent.singleton_class.send(:define_method, :retrieve) do |*_args|
      OpenStruct.new(id: "pi_test_123", client_secret: "pi_test_123_secret_abc")
    end

    yield
  ensure
    Stripe::PaymentIntent.singleton_class.send(:define_method, :retrieve, original_retrieve)
  end
end
