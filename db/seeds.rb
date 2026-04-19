require "json"
require "open-uri"
require "uri"

puts "== Rooted in Winnipeg seeds =="

CATEGORY_NAMES = [
  "Tropicals",
  "Succulents & Cacti",
  "Herbs & Edibles",
  "Low Light",
  "Outdoor Seasonal"
].freeze

PROVINCE_ROWS = [
  { name: "Alberta", abbreviation: "AB", gst_rate: 0.05, pst_rate: 0.0, hst_rate: 0.0 },
  { name: "British Columbia", abbreviation: "BC", gst_rate: 0.05, pst_rate: 0.07, hst_rate: 0.0 },
  { name: "Manitoba", abbreviation: "MB", gst_rate: 0.05, pst_rate: 0.07, hst_rate: 0.0 },
  { name: "New Brunswick", abbreviation: "NB", gst_rate: 0.0, pst_rate: 0.0, hst_rate: 0.15 },
  { name: "Newfoundland and Labrador", abbreviation: "NL", gst_rate: 0.0, pst_rate: 0.0, hst_rate: 0.15 },
  { name: "Northwest Territories", abbreviation: "NT", gst_rate: 0.05, pst_rate: 0.0, hst_rate: 0.0 },
  { name: "Nova Scotia", abbreviation: "NS", gst_rate: 0.0, pst_rate: 0.0, hst_rate: 0.14 },
  { name: "Nunavut", abbreviation: "NU", gst_rate: 0.05, pst_rate: 0.0, hst_rate: 0.0 },
  { name: "Ontario", abbreviation: "ON", gst_rate: 0.0, pst_rate: 0.0, hst_rate: 0.13 },
  { name: "Prince Edward Island", abbreviation: "PE", gst_rate: 0.0, pst_rate: 0.0, hst_rate: 0.15 },
  { name: "Quebec", abbreviation: "QC", gst_rate: 0.05, pst_rate: 0.09975, hst_rate: 0.0 },
  { name: "Saskatchewan", abbreviation: "SK", gst_rate: 0.05, pst_rate: 0.06, hst_rate: 0.0 },
  { name: "Yukon", abbreviation: "YT", gst_rate: 0.05, pst_rate: 0.0, hst_rate: 0.0 }
].freeze

SEED_TARGET_PRODUCTS = 3000
CACHE_FILE_PATH = Rails.root.join("db", "seeds", "perenual_species_cache.json")
SEED_ATTACH_IMAGES = ENV.fetch("SEED_ATTACH_IMAGES", "false") == "true"

def image_url_for(species_row)
  image_data = species_row["default_image"] || {}
  image_data["regular_url"] || image_data["original_url"] || image_data["medium_url"] || image_data["small_url"]
end

def attach_product_image(product, image_url)
  unless SEED_ATTACH_IMAGES
    unless defined?(@seed_image_attach_notice_printed) && @seed_image_attach_notice_printed
      puts "Image attachment disabled (set SEED_ATTACH_IMAGES=true to enable)."
      @seed_image_attach_notice_printed = true
    end
    return
  end

  return if image_url.blank? || product.image.attached?

  image_io = URI.open(image_url)
  filename = File.basename(URI.parse(image_url).path)
  filename = "product-#{product.perenual_id || product.id}.jpg" if filename.blank?

  product.image.attach(io: image_io, filename: filename)
rescue StandardError => e
  puts "Image attach skipped for #{product.name}: #{e.message}"
end

def seed_categories!
  CATEGORY_NAMES.each do |name|
    Category.find_or_create_by!(name: name)
  end

  puts "Seeded categories: #{Category.count}"
end

def seed_provinces!
  PROVINCE_ROWS.each do |row|
    province = Province.find_or_initialize_by(abbreviation: row[:abbreviation])
    province.update!(row)
  end

  puts "Seeded provinces/territories: #{Province.count}"
end

def load_cache_file
  unless File.exist?(CACHE_FILE_PATH)
    puts "Cache file not found: #{CACHE_FILE_PATH}"
    return []
  end
  payload = JSON.parse(File.read(CACHE_FILE_PATH))
  rows = payload["rows"] || []
  puts "Loaded cache file: #{CACHE_FILE_PATH} (rows: #{rows.size})"
  rows
rescue StandardError => e
  puts "Cache read failed: #{e.message}"
  []
end

def seed_products_from_perenual!
  rows_for_seed = load_cache_file
  if rows_for_seed.empty?
    puts "No cached rows available. Skipping product seed."
    return
  end

  processed = 0

  rows_for_seed.each do |species_row|
    category_name = species_row["_seed_category"] || "Tropicals"
    category = Category.find_by!(name: category_name)

    perenual_id = species_row["id"]
    next if perenual_id.blank?

    scientific_name = Array(species_row["scientific_name"]).first
    name = species_row["common_name"].presence || scientific_name
    next if name.blank?

    product = Product.find_or_initialize_by(perenual_id: perenual_id)
    next if product.new_record? && Product.count >= SEED_TARGET_PRODUCTS

    raw_sunlight = Array(species_row["sunlight"]).join(", ")
    raw_watering = species_row["watering"].to_s
    raw_family = species_row["family"].to_s
    raw_genus = species_row["genus"].to_s
    sunlight_value = raw_sunlight.presence || "mixed light"
    watering_value = raw_watering.presence || "average"
    family_value = raw_family.presence || "Not specified"
    genus_value = raw_genus.presence || "Not specified"

    product.name = name
    product.scientific_name = scientific_name
    product.description = nil
    product.watering = watering_value
    product.sunlight = sunlight_value
    product.family = family_value
    product.genus = genus_value
    product.price ||= Faker::Commerce.price(range: 8.99..89.99).to_d
    product.stock ||= Faker::Number.between(from: 5, to: 50)
    product.category = category
    product.save!
    attach_product_image(product, image_url_for(species_row))

    processed += 1
  end

  puts "Perenual rows processed from cache: #{processed}"
  puts "Products now in database: #{Product.count}"
end

seed_categories!
seed_provinces!
seed_products_from_perenual!

puts "== Seeding complete =="
AdminUser.create!(email: 'admin@example.com', password: 'password', password_confirmation: 'password') if Rails.env.development?