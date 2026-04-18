class RemovePoisonousFieldsFromProducts < ActiveRecord::Migration[8.1]
  def change
    remove_column :products, :poisonous_to_pets, :boolean
    remove_column :products, :poisonous_to_humans, :boolean
  end
end
