ActiveAdmin.register Order do
  permit_params :status

  index do
    selectable_column
    id_column
    column :user
    column :status
    column("Total") { |order| number_to_currency(order.total_cents.to_f / 100) }
    column :created_at
    actions
  end

  filter :user
  filter :status, as: :select, collection: Order.statuses.keys
  filter :created_at

  show do
    attributes_table do
      row :id
      row :user
      row :status
      row("Subtotal") { |order| number_to_currency(order.subtotal_cents.to_f / 100) }
      row("Tax") { |order| number_to_currency(order.tax_amount_cents.to_f / 100) }
      row("Total") { |order| number_to_currency(order.total_cents.to_f / 100) }
      row :shipping_address
      row :province_snapshot
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs do
      f.input :status, as: :select, collection: Order.statuses.keys
    end
    f.actions
  end
end
