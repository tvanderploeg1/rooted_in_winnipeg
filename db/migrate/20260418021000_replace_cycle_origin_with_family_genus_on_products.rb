class ReplaceCycleOriginWithFamilyGenusOnProducts < ActiveRecord::Migration[8.1]
  def change
    remove_column :products, :cycle, :string if column_exists?(:products, :cycle)
    remove_column :products, :origin, :string if column_exists?(:products, :origin)

    add_column :products, :family, :string unless column_exists?(:products, :family)
    add_column :products, :genus, :string unless column_exists?(:products, :genus)
  end
end
