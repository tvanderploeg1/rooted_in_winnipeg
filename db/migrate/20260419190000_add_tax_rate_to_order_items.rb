class AddTaxRateToOrderItems < ActiveRecord::Migration[8.1]
  def change
    add_column :order_items, :tax_rate, :decimal, precision: 5, scale: 4, null: false, default: 0.0
  end
end
