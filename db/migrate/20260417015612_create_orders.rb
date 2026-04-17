class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false
      t.integer :total_cents, null: false
      t.integer :tax_amount_cents
      t.string :stripe_payment_id
      t.string :stripe_customer_id
      t.string :shipping_address
      t.string :province_snapshot

      t.timestamps
    end
  end
end
