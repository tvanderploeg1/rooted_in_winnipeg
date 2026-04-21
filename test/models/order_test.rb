require "test_helper"

class OrderTest < ActiveSupport::TestCase
  setup do
    @province = Province.create!(
      name: "Order Test Province",
      abbreviation: "OT",
      gst_rate: 0.05,
      pst_rate: 0.07,
      hst_rate: 0.0
    )

    @user = User.create!(
      email: "order-model-test@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      full_name: "Order Model Test",
      address: "100 Test Ave",
      city: "Winnipeg",
      postal_code: "R3C0V8",
      province: @province
    )
  end

  test "allows pending to paid transition" do
    order = build_order(status: "pending")

    assert order.transition_to("paid")
    assert_equal "paid", order.reload.status
  end

  test "allows paid to shipped transition" do
    order = build_order(status: "pending")
    order.transition_to("paid")

    assert order.transition_to("shipped")
    assert_equal "shipped", order.reload.status
  end

  test "blocks pending to shipped transition" do
    order = build_order(status: "pending")

    assert_not order.transition_to("shipped")
    assert_equal "pending", order.reload.status
  end

  test "blocks shipped to pending transition" do
    order = build_order(status: "pending")
    order.transition_to("paid")
    order.transition_to("shipped")

    assert_not order.transition_to("pending")
    assert_equal "shipped", order.reload.status
  end

  test "blocks failed to paid transition" do
    order = build_order(status: "failed")

    assert order.transition_to("paid")
    assert_equal "paid", order.reload.status
  end

  test "allows pending to cancelled transition" do
    order = build_order(status: "pending")

    assert order.transition_to("cancelled")
    assert_equal "cancelled", order.reload.status
  end

  test "blocks cancelled to paid transition" do
    order = build_order(status: "pending")
    order.transition_to("cancelled")

    assert_not order.transition_to("paid")
    assert_equal "cancelled", order.reload.status
  end

  private

  def build_order(status:)
    @user.orders.create!(
      status: status,
      total_cents: 2500,
      tax_amount_cents: 300,
      shipping_address: "100 Test Ave, Winnipeg, R3C0V8",
      province_snapshot: "Manitoba"
    )
  end
end
