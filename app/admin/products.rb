ActiveAdmin.register Product do
  permit_params :name, :scientific_name, :description, :watering, :sunlight,
                :family, :genus, :price, :stock, :perenual_id, :category_id, :image

  index do
    selectable_column
    id_column
    column :name
    column :scientific_name
    column :category
    column :price
    column :stock
    column :created_at
    actions
  end

  filter :name
  filter :scientific_name
  filter :category
  filter :price
  filter :stock
  filter :created_at

  form do |f|
    f.inputs do
      f.input :name
      f.input :scientific_name
      f.input :description
      f.input :watering
      f.input :sunlight
      f.input :family
      f.input :genus
      f.input :price, input_html: { min: 0.01, step: 0.01 }
      f.input :stock, input_html: { min: 0, step: 1 }
      f.input :perenual_id
      f.input :category
      f.input :image, as: :file
    end
    f.actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :scientific_name
      row :description
      row :watering
      row :sunlight
      row :family
      row :genus
      row :price
      row :stock
      row :perenual_id
      row :category
      row :created_at
      row :updated_at
      row :image do |product|
        if product.image.attached?
          image_tag url_for(product.image), style: "max-width: 140px; height: auto;"
        else
          "No image"
        end
      end
    end
  end
end
