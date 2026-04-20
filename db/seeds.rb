require "json"
require "open-uri"
require "set"
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

SEED_TARGET_PRODUCTS = 750
PRODUCTS_PER_CATEGORY = SEED_TARGET_PRODUCTS / CATEGORY_NAMES.size
PERENUAL_API_BASE_URL = "https://perenual.com/api/v2/species-list"
MAX_API_PAGES = 95

PERENUAL_API_KEY = ENV["PERENUAL_API_KEY"].to_s
if PERENUAL_API_KEY.blank?
  raise "Missing PERENUAL_API_KEY in environment."
end

if ENV["SEED_TARGET_PRODUCTS"].present?
  target_override = ENV["SEED_TARGET_PRODUCTS"].to_i
  if target_override.positive?
    Object.send(:remove_const, :SEED_TARGET_PRODUCTS)
    Object.send(:remove_const, :PRODUCTS_PER_CATEGORY)
    SEED_TARGET_PRODUCTS = target_override
    PRODUCTS_PER_CATEGORY = (SEED_TARGET_PRODUCTS.to_f / CATEGORY_NAMES.size).ceil
  end
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

def upsert_seed_product!(species_row:, category_name:, category_lookup:, seen_common_names:)
  perenual_id = species_row["id"].to_i
  return false if perenual_id <= 0

  scientific_name = Array(species_row["scientific_name"]).first.to_s.strip
  common_name = species_row["common_name"].to_s.strip
  return false if maple_common_name?(common_name)

  normalized_common_name = normalize_common_name(common_name)
  return false if normalized_common_name.present? && seen_common_names.include?(normalized_common_name)

  name = common_name.presence || scientific_name
  return false if name.blank?

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
  product.price ||= (((perenual_id % 80) + 10).to_d + 0.99)
  product.stock ||= 5 + (perenual_id % 46)
  product.category = category_lookup[category_name] if was_new || product.category.blank?

  product.save!
  attach_product_image(product, species_row)
  seen_common_names << normalized_common_name if normalized_common_name.present?
  was_new
end

def image_url_for(species_row)
  image_data = species_row["default_image"] || {}
  [ image_data["regular_url"], image_data["medium_url"], image_data["small_url"], image_data["thumbnail"] ]
    .find { |url| url.to_s.start_with?("https://") }
end

def attach_product_image(product, species_row)
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
      nil
    rescue StandardError => e
      puts "Image fetch failed for #{product.name}: #{e.message}"
    end
  end
end

def classify_category_name(species_row)
  family = species_row["family"].to_s.downcase
  genus = species_row["genus"].to_s.downcase
  name = species_row["common_name"].to_s.downcase
  sunlight = Array(species_row["sunlight"]).join(" ").downcase
  watering = species_row["watering"].to_s.downcase

  return "Succulents & Cacti" if family.match?(/cactaceae|crassulaceae|aizoaceae|asphodelaceae/) ||
    genus.match?(/aloe|haworthia|echeveria|sedum|opuntia|mammillaria/) ||
    name.match?(/cactus|succulent/) ||
    watering.match?(/minimum|infrequent|\blow\b/)

  return "Herbs & Edibles" if family.match?(/lamiaceae|apiaceae|brassicaceae|solanaceae/) ||
    genus.match?(/ocimum|mentha|petroselinum|coriandrum|thymus|rosmarinus|salvia/) ||
    name.match?(/basil|mint|parsley|cilantro|thyme|rosemary|oregano|dill|chive|sage|lettuce|kale|tomato|pepper/)

  return "Low Light" if sunlight.match?(/shade|partial shade|indirect|low light/)

  return "Outdoor Seasonal" if sunlight.match?(/full sun|direct sun/) && !watering.match?(/frequent|\bhigh\b/)

  return "Tropicals" if family.match?(/araceae|marantaceae|musaceae|bromeliaceae|orchidaceae/) ||
    genus.match?(/monstera|philodendron|pothos|calathea|maranta|anthurium|ficus|dracaena/) ||
    sunlight.match?(/bright indirect|filtered/)

  nil
end

def choose_category_name(species_row, category_counts)
  predicted = classify_category_name(species_row)
  return predicted if predicted.present?

  nil
end

def maple_common_name?(common_name)
  common_name.to_s.downcase.include?("maple")
end

def normalize_common_name(common_name)
  common_name.to_s.downcase.strip.gsub(/\s+/, " ")
end

def seed_products_from_perenual!
  category_lookup = Category.where(name: CATEGORY_NAMES).index_by(&:name)
  seen_common_names = Product.where.not(name: [ nil, "" ]).pluck(:name).map { |name| normalize_common_name(name) }.to_set

  category_counts = CATEGORY_NAMES.index_with do |name|
    category_lookup[name].products.count
  end

  created_count = 0
  page = 1
  while category_counts.values.sum < SEED_TARGET_PRODUCTS && page <= MAX_API_PAGES
    rows = fetch_species_page(page)
    break if rows.empty?

    rows.each do |species_row|
      break if category_counts.values.sum >= SEED_TARGET_PRODUCTS

      category_name = choose_category_name(species_row, category_counts)
      next if category_name.blank?

      if upsert_seed_product!(
        species_row: species_row,
        category_name: category_name,
        category_lookup: category_lookup,
        seen_common_names: seen_common_names
      )
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
if Rails.env.development?
  AdminUser.find_or_create_by!(email: "admin@example.com") do |admin|
    admin.password = "password"
    admin.password_confirmation = "password"
  end
end
