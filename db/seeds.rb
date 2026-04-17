require "json"
require "net/http"
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
  { name: "Nova Scotia", abbreviation: "NS", gst_rate: 0.0, pst_rate: 0.0, hst_rate: 0.15 },
  { name: "Nunavut", abbreviation: "NU", gst_rate: 0.05, pst_rate: 0.0, hst_rate: 0.0 },
  { name: "Ontario", abbreviation: "ON", gst_rate: 0.0, pst_rate: 0.0, hst_rate: 0.13 },
  { name: "Prince Edward Island", abbreviation: "PE", gst_rate: 0.0, pst_rate: 0.0, hst_rate: 0.15 },
  { name: "Quebec", abbreviation: "QC", gst_rate: 0.05, pst_rate: 0.09975, hst_rate: 0.0 },
  { name: "Saskatchewan", abbreviation: "SK", gst_rate: 0.05, pst_rate: 0.06, hst_rate: 0.0 },
  { name: "Yukon", abbreviation: "YT", gst_rate: 0.05, pst_rate: 0.0, hst_rate: 0.0 }
].freeze

PERENUAL_BASE_URL = "https://perenual.com/api/v2/species-list"
SEED_TARGET_PRODUCTS = 500
PER_PAGE = 30
MAX_PAGES = 10

CATEGORY_FILTERS = {
  "Succulents & Cacti" => { sunlight: "full_sun", watering: "minimum" },
  "Low Light" => { sunlight: "part_shade" },
  "Outdoor Seasonal" => { cycle: "annual" },
  "Herbs & Edibles" => { edible: 1 },
  "Tropicals" => { indoor: 1 }
}.freeze

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

def fetch_perenual_page(page, api_key, filters = {})
  params = { key: api_key, page: page, per_page: PER_PAGE }.merge(filters)
  uri = URI.parse(PERENUAL_BASE_URL)
  uri.query = URI.encode_www_form(params)
  response = Net::HTTP.get_response(uri)
  unless response.is_a?(Net::HTTPSuccess)
    puts "Skipped page #{page}: HTTP #{response.code}"
    return {}
  end

  JSON.parse(response.body)
rescue StandardError => e
  puts "Skipped page #{page}: #{e.message}"
  {}
end

def seed_products_from_perenual!
  api_key = ENV["PERENUAL_API_KEY"]
  if api_key.blank?
    puts "PERENUAL_API_KEY not set. Skipping API product seed."
    return
  end

  processed = 0

  CATEGORY_FILTERS.each do |category_name, filters|
    break if Product.count >= SEED_TARGET_PRODUCTS

    category = Category.find_by!(name: category_name)
    page = 1

    while Product.count < SEED_TARGET_PRODUCTS && page <= MAX_PAGES
      payload = fetch_perenual_page(page, api_key, filters)
      rows = payload["data"] || []
      break if rows.empty?

      rows.each do |species_row|
        break if Product.count >= SEED_TARGET_PRODUCTS

        perenual_id = species_row["id"]
        next if perenual_id.blank?

        scientific_name = Array(species_row["scientific_name"]).first
        name = species_row["common_name"].presence || scientific_name
        next if name.blank?

        product = Product.find_or_initialize_by(perenual_id: perenual_id)
        if product.new_record?
          product = Product.find_or_initialize_by(name: name, scientific_name: scientific_name)
        end
        next if product.persisted? && product.perenual_id.present? && product.perenual_id != perenual_id

        sunlight_value = Array(species_row["sunlight"]).join(", ").presence || filters[:sunlight].to_s.tr("_", " ")
        watering_value = species_row["watering"].presence || filters[:watering].to_s.tr("_", " ")

        product.name = name
        product.scientific_name = scientific_name
        product.description = "Watering: #{watering_value.presence || "average"}. Sunlight: #{sunlight_value.presence || "mixed light"}."
        product.watering = watering_value.presence || "average"
        product.sunlight = sunlight_value.presence || "mixed light"
        product.poisonous_to_pets = species_row["poisonous_to_pets"] || false
        product.poisonous_to_humans = species_row["poisonous_to_humans"] || false
        product.price ||= rand(8.99..89.99).round(2).to_d
        product.stock ||= rand(5..50)
        product.category = category
        product.perenual_id ||= perenual_id
        product.save!

        processed += 1
      end

      puts "Processed #{category_name} page #{page} (products total: #{Product.count})"
      page += 1
    end
  end

  puts "Perenual rows processed: #{processed}"
  puts "Products now in database: #{Product.count}"
end

seed_categories!
seed_provinces!
seed_products_from_perenual!

puts "== Seeding complete =="
