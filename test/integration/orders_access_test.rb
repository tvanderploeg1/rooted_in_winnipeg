require "test_helper"

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
end
