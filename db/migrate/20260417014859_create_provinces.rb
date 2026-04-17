class CreateProvinces < ActiveRecord::Migration[8.1]
  def change
    create_table :provinces do |t|
      t.string :name, null: false
      t.string :abbreviation, null: false
      t.decimal :gst_rate
      t.decimal :pst_rate
      t.decimal :hst_rate

      t.timestamps
    end
  end
end
