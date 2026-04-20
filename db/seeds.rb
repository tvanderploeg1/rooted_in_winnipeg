require "json"
require "open-uri"
require "uri"
require "stringio"

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

SEED_TARGET_PRODUCTS = 750
PRODUCTS_PER_CATEGORY = SEED_TARGET_PRODUCTS / CATEGORY_NAMES.size # 150 each
PERENUAL_API_BASE_URL = "https://perenual.com/api/v2/species-list"
MAX_API_PAGES = 95
FALLBACK_IMAGE_BY_CATEGORY = {
  "Tropicals" => "tropicals_stock_photo.png",
  "Succulents & Cacti" => "succulents_cacti_stock_photo.png",
  "Herbs & Edibles" => "herb_edibles_stock_photo.png",
  "Low Light" => "low_light_stock_photo.png",
  "Outdoor Seasonal" => "outdoor_seasonal_stock_photo.png"
}.freeze

PERENUAL_API_KEY = ENV["PERENUAL_API_KEY"].to_s
if PERENUAL_API_KEY.blank?
  raise "Missing PERENUAL_API_KEY in environment."
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

def generated_description_for(name:, scientific_name:, family:, watering:, sunlight:)
  care_sentence = "#{name} thrives in #{sunlight.downcase} and prefers #{watering.downcase} watering."
  botanical_sentence = if scientific_name.present?
    "Known botanically as #{scientific_name}, it belongs to the #{family} family."
  else
    "This variety belongs to the #{family} family."
  end
  [ botanical_sentence, care_sentence ].join(" ")
end

def fetch_species_page(page)
  query = URI.encode_www_form(key: PERENUAL_API_KEY, page: page)
  url = "#{PERENUAL_API_BASE_URL}?#{query}"

  response = URI.open(
    url,
    "User-Agent" => "RootedInWinnipegSeeds/1.0",
    open_timeout: 10,
    read_timeout: 20
  ).read

  payload = JSON.parse(response)
  payload["data"] || []
rescue StandardError => e
  puts "Perenual fetch failed on page #{page}: #{e.message}"
  []
end

def image_url_for(species_row)
  image_data = species_row["default_image"] || {}
  [ image_data["regular_url"], image_data["medium_url"], image_data["small_url"], image_data["thumbnail"] ]
    .find { |url| url.to_s.start_with?("https://") }
end

def attach_fallback_image(product, category_name)
  return if product.image.attached?

  fallback_filename = FALLBACK_IMAGE_BY_CATEGORY[category_name]
  fallback_path = Rails.root.join("app", "assets", "images", fallback_filename) if fallback_filename.present?
  if fallback_path.present? && File.exist?(fallback_path)
    product.image.attach(
      io: File.open(fallback_path),
      filename: File.basename(fallback_path),
      content_type: "image/png"
    )
    return
  end

  # Last-resort fallback so every seeded product still has an image.
  label = product.name.to_s[0, 32]
  svg = <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" width="600" height="450">
      <rect width="100%" height="100%" fill="#f5f5f5"/>
      <text x="50%" y="50%" text-anchor="middle" fill="#888" font-size="22" font-family="Arial">
        #{label.presence || "Plant image unavailable"}
      </text>
    </svg>
  SVG
  product.image.attach(io: StringIO.new(svg), filename: "fallback-#{product.perenual_id || product.id}.svg", content_type: "image/svg+xml")
end

def attach_product_image(product, species_row, category_name)
  return if product.image.attached?

  image_url = image_url_for(species_row)
  if image_url.present?
    begin
      image_io = URI.open(
        image_url,
        "User-Agent" => "Mozilla/5.0",
        open_timeout: 10,
        read_timeout: 20
      )
      ext = File.extname(URI.parse(image_url).path).presence || ".jpg"
      product.image.attach(io: image_io, filename: "product-#{product.perenual_id || product.id}#{ext}")
      return
    rescue StandardError => e
      puts "Image fetch failed for #{product.name}: #{e.message}"
    end
  end

  attach_fallback_image(product, category_name)
end

def next_category_name(category_counts)
  CATEGORY_NAMES.find { |name| category_counts[name] < PRODUCTS_PER_CATEGORY }
end

def seed_products_from_perenual!
  category_lookup = Category.where(name: CATEGORY_NAMES).index_by(&:name)

  category_counts = CATEGORY_NAMES.index_with do |name|
    category_lookup[name].products.count
  end

  page = 1
  created_count = 0

  while category_counts.values.sum < SEED_TARGET_PRODUCTS && page <= MAX_API_PAGES
    rows = fetch_species_page(page)
    break if rows.empty?

    rows.each do |species_row|
      category_name = next_category_name(category_counts)
      break if category_name.blank?

      perenual_id = species_row["id"].to_i
      next if perenual_id <= 0

      scientific_name = Array(species_row["scientific_name"]).first.to_s.strip
      common_name = species_row["common_name"].to_s.strip
      name = common_name.presence || scientific_name
      next if name.blank?

      raw_sunlight = Array(species_row["sunlight"]).join(", ")
      raw_watering = species_row["watering"].to_s
      raw_family = species_row["family"].to_s
      raw_genus = species_row["genus"].to_s

      sunlight_value = raw_sunlight.presence || "mixed light"
      watering_value = raw_watering.presence || "average"
      family_value = raw_family.presence || "Not specified"
      genus_value = raw_genus.presence || "Not specified"

      product = Product.find_or_initialize_by(perenual_id: perenual_id)
      was_new = product.new_record?

      product.name = name
      product.scientific_name = scientific_name
      product.description = generated_description_for(
        name: name,
        scientific_name: scientific_name,
        family: family_value,
        watering: watering_value,
        sunlight: sunlight_value
      ) if product.description.blank?
      product.watering = watering_value
      product.sunlight = sunlight_value
      product.family = family_value
      product.genus = genus_value
      product.price ||= (((perenual_id % 80) + 10).to_d + 0.99) # deterministic student-level price
      product.stock ||= 5 + (perenual_id % 46)                  # deterministic stock 5..50
      product.category = category_lookup[category_name] if was_new || product.category.blank?

      product.save!
      attach_product_image(product, species_row, category_name)

      if was_new
        category_counts[category_name] += 1
        created_count += 1
      end
    end

    page += 1
    sleep 0.2
  end

  if category_counts.values.sum < SEED_TARGET_PRODUCTS
    puts "Stopped at page #{page - 1}; seeded #{category_counts.values.sum}/#{SEED_TARGET_PRODUCTS} products within API call cap."
  end

  puts "Created from API this run: #{created_count}"
  puts "Products now in database: #{Product.count}"
  puts "Category counts: #{category_counts.inspect}"
end

seed_categories!
seed_provinces!
seed_products_from_perenual!

puts "== Seeding complete =="
AdminUser.create!(email: "admin@example.com", password: "password", password_confirmation: "password") if Rails.env.development?