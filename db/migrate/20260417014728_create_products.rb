class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :scientific_name
      t.text :description
      t.string :watering
      t.string :sunlight
      t.boolean :poisonous_to_pets, default: false
      t.boolean :poisonous_to_humans, default: false
      t.decimal :price, null: false
      t.integer :stock, null: false
      t.integer :perenual_id
      t.references :category, null: false, foreign_key: true

      t.timestamps
    end
  end
end
