# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding work categories..."

categories = {
  "Maçonnerie" => "maconnerie",
  "Plomberie" => "plomberie",
  "Électricité" => "electricite",
  "Menuiserie" => "menuiserie",
  "Peinture" => "peinture",
  "Carrelage" => "carrelage",
  "Isolation" => "isolation",
  "Chauffage" => "chauffage"
}

categories.each do |name, slug|
  WorkCategory.find_or_create_by!(slug: slug) { |c| c.name = name }
end

puts "Seeding materials..."

materials_data = [
  { brand: "Weber", reference: "weber.col 822", unit: "kg", public_price_exVAT: 1.20, vat_rate: 10, category: "carrelage" },
  { brand: "Knauf", reference: "BA13", unit: "m2", public_price_exVAT: 5.50, vat_rate: 10, category: "isolation" },
  { brand: "Legrand", reference: "076 54", unit: "pce", public_price_exVAT: 12.00, vat_rate: 20, category: "electricite" },
  { brand: "Grohe", reference: "32867000", unit: "pce", public_price_exVAT: 185.00, vat_rate: 10, category: "plomberie" },
  { brand: "Sika", reference: "SikaTop-107 Seal", unit: "kg", public_price_exVAT: 3.80, vat_rate: 10, category: "maconnerie" },
  { brand: "Dulux Valentine", reference: "Crème de Couleur", unit: "L", public_price_exVAT: 18.50, vat_rate: 10, category: "peinture" },
  { brand: "Porcelanosa", reference: "RODANO CALIZA", unit: "m2", public_price_exVAT: 42.00, vat_rate: 10, category: "carrelage" },
  { brand: "Isover", reference: "Isoconfort 35", unit: "m2", public_price_exVAT: 8.90, vat_rate: 10, category: "isolation" },
  { brand: "Schneider", reference: "Mureva Styl", unit: "pce", public_price_exVAT: 9.50, vat_rate: 20, category: "electricite" },
  { brand: "Atlantic", reference: "Alféa Extensa Duo", unit: "pce", public_price_exVAT: 3200.00, vat_rate: 5, category: "chauffage" }
]

materials_data.each do |m|
  category = WorkCategory.find_by!(slug: m[:category])
  Material.find_or_create_by!(brand: m[:brand], reference: m[:reference]) do |mat|
    mat.work_category = category
    mat.unit = m[:unit]
    mat.public_price_exVAT = m[:public_price_exVAT]
    mat.vat_rate = m[:vat_rate]
  end
end

puts "Seeding demo user..."

user = User.find_or_create_by!(email: "demo@opendevis.com") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
end

puts "Seeding demo project..."

project = Project.find_or_create_by!(user: user, status: "draft") do |p|
  p.location_zip = "75011"
  p.room_count = 3
  p.total_surface_sqm = 65.0
  p.energy_rating = "D"
  p.property_url = "https://example.com/annonce/123"
end

puts "Seeding rooms..."

rooms_data = [
  { name: "Salon", surface_sqm: 25.0, perimeter_lm: 20.0, wall_height_m: 2.5 },
  { name: "Cuisine", surface_sqm: 12.0, perimeter_lm: 14.0, wall_height_m: 2.5 },
  { name: "Salle de bain", surface_sqm: 6.0, perimeter_lm: 10.0, wall_height_m: 2.5 }
]

rooms_data.each do |r|
  Room.find_or_create_by!(project: project, name: r[:name]) do |room|
    room.surface_sqm = r[:surface_sqm]
    room.perimeter_lm = r[:perimeter_lm]
    room.wall_height_m = r[:wall_height_m]
  end
end

puts "Seeding work items..."

work_items_data = [
  {
    room: "Salon", label: "Peinture murs et plafond", category: "peinture",
    material: { brand: "Dulux Valentine", reference: "Crème de Couleur" },
    quantity: 5, unit: "L", unit_price_exVAT: 18.50, vat_rate: 10, standing_level: 1
  },
  {
    room: "Salle de bain", label: "Pose carrelage sol", category: "carrelage",
    material: { brand: "Porcelanosa", reference: "RODANO CALIZA" },
    quantity: 6, unit: "m2", unit_price_exVAT: 42.00, vat_rate: 10, standing_level: 2
  },
  {
    room: "Salle de bain", label: "Joint carrelage", category: "carrelage",
    material: { brand: "Weber", reference: "weber.col 822" },
    quantity: 3, unit: "kg", unit_price_exVAT: 1.20, vat_rate: 10, standing_level: 2
  },
  {
    room: "Cuisine", label: "Isolation murs", category: "isolation",
    material: { brand: "Knauf", reference: "BA13" },
    quantity: 10, unit: "m2", unit_price_exVAT: 5.50, vat_rate: 10, standing_level: 1
  }
]

work_items_data.each do |wi|
  room = Room.find_by!(project: project, name: wi[:room])
  category = WorkCategory.find_by!(slug: wi[:category])
  material = Material.find_by!(brand: wi[:material][:brand], reference: wi[:material][:reference])

  WorkItem.find_or_create_by!(room: room, label: wi[:label]) do |item|
    item.work_category = category
    item.material = material
    item.quantity = wi[:quantity]
    item.unit = wi[:unit]
    item.unit_price_exVAT = wi[:unit_price_exVAT]
    item.vat_rate = wi[:vat_rate]
    item.standing_level = wi[:standing_level]
  end
end

puts "Done! #{WorkCategory.count} categories, #{Material.count} materials, #{User.count} users, #{Project.count} projects, #{Room.count} rooms, #{WorkItem.count} work items."
