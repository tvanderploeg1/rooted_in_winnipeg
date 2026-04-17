class AddProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :full_name, :string
    add_column :users, :address, :string
    add_column :users, :city, :string
    add_column :users, :postal_code, :string
    add_reference :users, :province, null: true, foreign_key: true
  end
end
