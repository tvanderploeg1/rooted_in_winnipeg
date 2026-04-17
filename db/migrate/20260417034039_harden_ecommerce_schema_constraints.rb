class HardenEcommerceSchemaConstraints < ActiveRecord::Migration[8.1]
  def change
    add_index :categories, :name, unique: true
    add_index :provinces, :abbreviation, unique: true

    add_index :order_items, [ :order_id, :product_id ], unique: true

    change_column_default :orders, :status, from: nil, to: "pending"
    change_column_default :orders, :tax_amount_cents, from: nil, to: 0
  end
end
