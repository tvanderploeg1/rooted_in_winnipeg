class AddProductUniquenessIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :products, :perenual_id,
              unique: true,
              name: "index_products_on_perenual_id_unique"

    add_index :products, [:name, :scientific_name],
              unique: true,
              name: "index_products_on_name_and_scientific_name_unique"
  end
end
