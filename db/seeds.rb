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
  # Maçonnerie
  { brand: "Sika", reference: "SikaTop-107 Seal", unit: "kg", public_price_exVAT: 3.80, vat_rate: 10, category: "maconnerie" },
  { brand: "Weber", reference: "weber.rep 767", unit: "kg", public_price_exVAT: 2.10, vat_rate: 10, category: "maconnerie" },
  { brand: "Parex", reference: "Parexlanko 260", unit: "kg", public_price_exVAT: 1.85, vat_rate: 10, category: "maconnerie" },
  # Plomberie
  { brand: "Grohe", reference: "32867000", unit: "pce", public_price_exVAT: 185.00, vat_rate: 10, category: "plomberie" },
  { brand: "Jacob Delafon", reference: "E8174", unit: "pce", public_price_exVAT: 320.00, vat_rate: 10, category: "plomberie" },
  { brand: "Hansgrohe", reference: "72600000", unit: "pce", public_price_exVAT: 95.00, vat_rate: 10, category: "plomberie" },
  { brand: "Watts", reference: "RFV220", unit: "pce", public_price_exVAT: 22.50, vat_rate: 10, category: "plomberie" },
  # Électricité
  { brand: "Legrand", reference: "076 54", unit: "pce", public_price_exVAT: 12.00, vat_rate: 20, category: "electricite" },
  { brand: "Schneider", reference: "Mureva Styl", unit: "pce", public_price_exVAT: 9.50, vat_rate: 20, category: "electricite" },
  { brand: "Hager", reference: "TG206B", unit: "pce", public_price_exVAT: 48.00, vat_rate: 20, category: "electricite" },
  { brand: "Philips", reference: "CorePro LEDspot", unit: "pce", public_price_exVAT: 4.90, vat_rate: 20, category: "electricite" },
  # Menuiserie
  { brand: "Velux", reference: "GGL 304", unit: "pce", public_price_exVAT: 410.00, vat_rate: 10, category: "menuiserie" },
  { brand: "Lapeyre", reference: "Porte Tokio", unit: "pce", public_price_exVAT: 185.00, vat_rate: 10, category: "menuiserie" },
  { brand: "Leroy Merlin", reference: "Parquet chêne massif", unit: "m2", public_price_exVAT: 38.00, vat_rate: 10, category: "menuiserie" },
  { brand: "Knauf", reference: "Plaque de plâtre BA15", unit: "m2", public_price_exVAT: 7.20, vat_rate: 10, category: "menuiserie" },
  # Peinture
  { brand: "Dulux Valentine", reference: "Crème de Couleur", unit: "L", public_price_exVAT: 18.50, vat_rate: 10, category: "peinture" },
  { brand: "Tollens", reference: "Primaire Universel", unit: "L", public_price_exVAT: 12.00, vat_rate: 10, category: "peinture" },
  { brand: "Zolpan", reference: "Satin Mural", unit: "L", public_price_exVAT: 15.80, vat_rate: 10, category: "peinture" },
  { brand: "Bondex", reference: "Lasure Bois Climat", unit: "L", public_price_exVAT: 22.00, vat_rate: 10, category: "peinture" },
  # Carrelage
  { brand: "Weber", reference: "weber.col 822", unit: "kg", public_price_exVAT: 1.20, vat_rate: 10, category: "carrelage" },
  { brand: "Porcelanosa", reference: "RODANO CALIZA", unit: "m2", public_price_exVAT: 42.00, vat_rate: 10, category: "carrelage" },
  { brand: "Marazzi", reference: "Terratech Stone Grey", unit: "m2", public_price_exVAT: 28.50, vat_rate: 10, category: "carrelage" },
  { brand: "Kerakoll", reference: "Fugabella Eco", unit: "kg", public_price_exVAT: 3.40, vat_rate: 10, category: "carrelage" },
  # Isolation
  { brand: "Knauf", reference: "BA13", unit: "m2", public_price_exVAT: 5.50, vat_rate: 10, category: "isolation" },
  { brand: "Isover", reference: "Isoconfort 35", unit: "m2", public_price_exVAT: 8.90, vat_rate: 10, category: "isolation" },
  { brand: "Rockwool", reference: "Rocksol 32", unit: "m2", public_price_exVAT: 11.20, vat_rate: 10, category: "isolation" },
  { brand: "Ursa", reference: "Terra 040", unit: "m2", public_price_exVAT: 9.60, vat_rate: 10, category: "isolation" },
  # Chauffage
  { brand: "Atlantic", reference: "Alféa Extensa Duo", unit: "pce", public_price_exVAT: 3200.00, vat_rate: 5, category: "chauffage" },
  { brand: "Saunier Duval", reference: "Isofast Condens F35", unit: "pce", public_price_exVAT: 1450.00, vat_rate: 10, category: "chauffage" },
  { brand: "Zehnder", reference: "Charleston 600", unit: "pce", public_price_exVAT: 380.00, vat_rate: 10, category: "chauffage" },
  { brand: "Purmo", reference: "Plan Compact Type 22", unit: "pce", public_price_exVAT: 145.00, vat_rate: 10, category: "chauffage" }
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

puts "Seeding users..."

alice = User.find_or_create_by!(email: "demo@opendevis.com") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
end

bob = User.find_or_create_by!(email: "bob@opendevis.com") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
end

puts "Seeding projects..."

projects_data = [
  {
    user: alice, location_zip: "75011", status: "draft",
    room_count: 4, total_surface_sqm: 65.0, energy_rating: "D",
    property_url: "https://example.com/annonce/123",
    rooms: [
      {
        name: "Salon", surface_sqm: 25.0, perimeter_lm: 20.0, wall_height_m: 2.5,
        work_items: [
          { label: "Peinture murs et plafond", category: "peinture", material: ["Dulux Valentine", "Crème de Couleur"], quantity: 5, unit: "L", unit_price_exVAT: 18.50, vat_rate: 10, standing_level: 1 },
          { label: "Pose parquet chêne", category: "menuiserie", material: ["Leroy Merlin", "Parquet chêne massif"], quantity: 25, unit: "m2", unit_price_exVAT: 38.00, vat_rate: 10, standing_level: 1 },
          { label: "Installation radiateur", category: "chauffage", material: ["Purmo", "Plan Compact Type 22"], quantity: 1, unit: "pce", unit_price_exVAT: 145.00, vat_rate: 10, standing_level: 2 }
        ]
      },
      {
        name: "Cuisine", surface_sqm: 12.0, perimeter_lm: 14.0, wall_height_m: 2.5,
        work_items: [
          { label: "Isolation murs", category: "isolation", material: ["Knauf", "BA13"], quantity: 10, unit: "m2", unit_price_exVAT: 5.50, vat_rate: 10, standing_level: 1 },
          { label: "Carrelage sol cuisine", category: "carrelage", material: ["Marazzi", "Terratech Stone Grey"], quantity: 12, unit: "m2", unit_price_exVAT: 28.50, vat_rate: 10, standing_level: 2 },
          { label: "Prise électrique encastrée", category: "electricite", material: ["Legrand", "076 54"], quantity: 6, unit: "pce", unit_price_exVAT: 12.00, vat_rate: 20, standing_level: 1 }
        ]
      },
      {
        name: "Salle de bain", surface_sqm: 6.0, perimeter_lm: 10.0, wall_height_m: 2.5,
        work_items: [
          { label: "Pose carrelage sol", category: "carrelage", material: ["Porcelanosa", "RODANO CALIZA"], quantity: 6, unit: "m2", unit_price_exVAT: 42.00, vat_rate: 10, standing_level: 2 },
          { label: "Joint carrelage", category: "carrelage", material: ["Weber", "weber.col 822"], quantity: 3, unit: "kg", unit_price_exVAT: 1.20, vat_rate: 10, standing_level: 2 },
          { label: "Robinet lavabo", category: "plomberie", material: ["Hansgrohe", "72600000"], quantity: 1, unit: "pce", unit_price_exVAT: 95.00, vat_rate: 10, standing_level: 2 },
          { label: "Spot LED encastré", category: "electricite", material: ["Philips", "CorePro LEDspot"], quantity: 4, unit: "pce", unit_price_exVAT: 4.90, vat_rate: 20, standing_level: 1 }
        ]
      },
      {
        name: "Chambre principale", surface_sqm: 14.0, perimeter_lm: 15.0, wall_height_m: 2.5,
        work_items: [
          { label: "Peinture murs", category: "peinture", material: ["Zolpan", "Satin Mural"], quantity: 4, unit: "L", unit_price_exVAT: 15.80, vat_rate: 10, standing_level: 1 },
          { label: "Isolation plafond", category: "isolation", material: ["Isover", "Isoconfort 35"], quantity: 14, unit: "m2", unit_price_exVAT: 8.90, vat_rate: 10, standing_level: 2 },
          { label: "Velux", category: "menuiserie", material: ["Velux", "GGL 304"], quantity: 1, unit: "pce", unit_price_exVAT: 410.00, vat_rate: 10, standing_level: 3 }
        ]
      }
    ]
  },
  {
    user: alice, location_zip: "69003", status: "sent",
    room_count: 2, total_surface_sqm: 38.0, energy_rating: "E",
    property_url: nil,
    rooms: [
      {
        name: "Séjour", surface_sqm: 22.0, perimeter_lm: 19.0, wall_height_m: 3.0,
        work_items: [
          { label: "Enduit de façade", category: "maconnerie", material: ["Parex", "Parexlanko 260"], quantity: 20, unit: "kg", unit_price_exVAT: 1.85, vat_rate: 10, standing_level: 2 },
          { label: "Peinture plafond", category: "peinture", material: ["Tollens", "Primaire Universel"], quantity: 3, unit: "L", unit_price_exVAT: 12.00, vat_rate: 10, standing_level: 1 },
          { label: "Tableau électrique", category: "electricite", material: ["Hager", "TG206B"], quantity: 1, unit: "pce", unit_price_exVAT: 48.00, vat_rate: 20, standing_level: 3 }
        ]
      },
      {
        name: "Salle d'eau", surface_sqm: 4.5, perimeter_lm: 8.5, wall_height_m: 2.5,
        work_items: [
          { label: "Étanchéité murs", category: "maconnerie", material: ["Sika", "SikaTop-107 Seal"], quantity: 10, unit: "kg", unit_price_exVAT: 3.80, vat_rate: 10, standing_level: 2 },
          { label: "Mitigeur douche", category: "plomberie", material: ["Grohe", "32867000"], quantity: 1, unit: "pce", unit_price_exVAT: 185.00, vat_rate: 10, standing_level: 2 },
          { label: "Carrelage mural", category: "carrelage", material: ["Marazzi", "Terratech Stone Grey"], quantity: 18, unit: "m2", unit_price_exVAT: 28.50, vat_rate: 10, standing_level: 2 }
        ]
      }
    ]
  },
  {
    user: alice, location_zip: "33000", status: "accepted",
    room_count: 5, total_surface_sqm: 110.0, energy_rating: "C",
    property_url: "https://example.com/annonce/456",
    rooms: [
      {
        name: "Entrée", surface_sqm: 8.0, perimeter_lm: 11.5, wall_height_m: 2.7,
        work_items: [
          { label: "Porte d'entrée", category: "menuiserie", material: ["Lapeyre", "Porte Tokio"], quantity: 1, unit: "pce", unit_price_exVAT: 185.00, vat_rate: 10, standing_level: 2 },
          { label: "Carrelage grès", category: "carrelage", material: ["Porcelanosa", "RODANO CALIZA"], quantity: 8, unit: "m2", unit_price_exVAT: 42.00, vat_rate: 10, standing_level: 1 }
        ]
      },
      {
        name: "Salon / Salle à manger", surface_sqm: 35.0, perimeter_lm: 24.0, wall_height_m: 2.7,
        work_items: [
          { label: "Pompe à chaleur", category: "chauffage", material: ["Atlantic", "Alféa Extensa Duo"], quantity: 1, unit: "pce", unit_price_exVAT: 3200.00, vat_rate: 5, standing_level: 3 },
          { label: "Peinture 2 couches", category: "peinture", material: ["Dulux Valentine", "Crème de Couleur"], quantity: 12, unit: "L", unit_price_exVAT: 18.50, vat_rate: 10, standing_level: 1 },
          { label: "Radiateur acier", category: "chauffage", material: ["Zehnder", "Charleston 600"], quantity: 2, unit: "pce", unit_price_exVAT: 380.00, vat_rate: 10, standing_level: 2 }
        ]
      },
      {
        name: "Cuisine ouverte", surface_sqm: 18.0, perimeter_lm: 17.0, wall_height_m: 2.7,
        work_items: [
          { label: "Chaudière gaz condensation", category: "chauffage", material: ["Saunier Duval", "Isofast Condens F35"], quantity: 1, unit: "pce", unit_price_exVAT: 1450.00, vat_rate: 10, standing_level: 3 },
          { label: "Vanne thermostatique", category: "plomberie", material: ["Watts", "RFV220"], quantity: 3, unit: "pce", unit_price_exVAT: 22.50, vat_rate: 10, standing_level: 2 },
          { label: "Isolation laine roche", category: "isolation", material: ["Rockwool", "Rocksol 32"], quantity: 18, unit: "m2", unit_price_exVAT: 11.20, vat_rate: 10, standing_level: 2 }
        ]
      }
    ]
  },
  {
    user: bob, location_zip: "13008", status: "draft",
    room_count: 3, total_surface_sqm: 55.0, energy_rating: "F",
    property_url: nil,
    rooms: [
      {
        name: "Living", surface_sqm: 28.0, perimeter_lm: 21.0, wall_height_m: 2.6,
        work_items: [
          { label: "Isolation thermique intérieure", category: "isolation", material: ["Ursa", "Terra 040"], quantity: 28, unit: "m2", unit_price_exVAT: 9.60, vat_rate: 10, standing_level: 2 },
          { label: "Reprise enduit", category: "maconnerie", material: ["Weber", "weber.rep 767"], quantity: 15, unit: "kg", unit_price_exVAT: 2.10, vat_rate: 10, standing_level: 1 },
          { label: "Spots encastrés LED", category: "electricite", material: ["Philips", "CorePro LEDspot"], quantity: 8, unit: "pce", unit_price_exVAT: 4.90, vat_rate: 20, standing_level: 1 }
        ]
      },
      {
        name: "Chambre 1", surface_sqm: 14.0, perimeter_lm: 15.0, wall_height_m: 2.6,
        work_items: [
          { label: "Lasure bois volets", category: "peinture", material: ["Bondex", "Lasure Bois Climat"], quantity: 2, unit: "L", unit_price_exVAT: 22.00, vat_rate: 10, standing_level: 2 },
          { label: "Plaque plâtre plafond", category: "menuiserie", material: ["Knauf", "Plaque de plâtre BA15"], quantity: 14, unit: "m2", unit_price_exVAT: 7.20, vat_rate: 10, standing_level: 2 }
        ]
      },
      {
        name: "WC + SDB", surface_sqm: 7.0, perimeter_lm: 11.0, wall_height_m: 2.6,
        work_items: [
          { label: "Colonne de douche", category: "plomberie", material: ["Jacob Delafon", "E8174"], quantity: 1, unit: "pce", unit_price_exVAT: 320.00, vat_rate: 10, standing_level: 2 },
          { label: "Faïence murale", category: "carrelage", material: ["Porcelanosa", "RODANO CALIZA"], quantity: 22, unit: "m2", unit_price_exVAT: 42.00, vat_rate: 10, standing_level: 2 },
          { label: "Joint époxy", category: "carrelage", material: ["Kerakoll", "Fugabella Eco"], quantity: 4, unit: "kg", unit_price_exVAT: 3.40, vat_rate: 10, standing_level: 2 },
          { label: "Interrupteur va-et-vient", category: "electricite", material: ["Schneider", "Mureva Styl"], quantity: 2, unit: "pce", unit_price_exVAT: 9.50, vat_rate: 20, standing_level: 1 }
        ]
      }
    ]
  }
]

projects_data.each do |pd|
  project = Project.find_or_create_by!(user: pd[:user], location_zip: pd[:location_zip]) do |p|
    p.status           = pd[:status]
    p.room_count       = pd[:room_count]
    p.total_surface_sqm = pd[:total_surface_sqm]
    p.energy_rating    = pd[:energy_rating]
    p.property_url     = pd[:property_url]
  end

  pd[:rooms].each do |rd|
    room = Room.find_or_create_by!(project: project, name: rd[:name]) do |r|
      r.surface_sqm   = rd[:surface_sqm]
      r.perimeter_lm  = rd[:perimeter_lm]
      r.wall_height_m = rd[:wall_height_m]
    end

    rd[:work_items].each do |wi|
      category = WorkCategory.find_by!(slug: wi[:category])
      material = Material.find_by!(brand: wi[:material][0], reference: wi[:material][1])

      WorkItem.find_or_create_by!(room: room, label: wi[:label]) do |item|
        item.work_category  = category
        item.material       = material
        item.quantity       = wi[:quantity]
        item.unit           = wi[:unit]
        item.unit_price_exVAT = wi[:unit_price_exVAT]
        item.vat_rate       = wi[:vat_rate]
        item.standing_level = wi[:standing_level]
      end
    end
  end
end

puts "Seeding documents..."

documents_data = [
  { user_email: "demo@opendevis.com", location_zip: "75011", docs: [
    { file_name: "Devis_Salon_v1.pdf", file_type: "PDF", file_url: "https://example.com/docs/devis_salon_v1.pdf" },
    { file_name: "Plans_appartement.pdf", file_type: "PDF", file_url: "https://example.com/docs/plans_appartement.pdf" },
    { file_name: "Photos_avant_travaux.jpg", file_type: "Image", file_url: "https://example.com/docs/photos_avant.jpg" }
  ]},
  { user_email: "demo@opendevis.com", location_zip: "69003", docs: [
    { file_name: "Devis_Plomberie.pdf", file_type: "PDF", file_url: "https://example.com/docs/devis_plomberie.pdf" },
    { file_name: "Facture_Maçonnerie.pdf", file_type: "PDF", file_url: "https://example.com/docs/facture_maconnerie.pdf" }
  ]},
  { user_email: "demo@opendevis.com", location_zip: "33000", docs: [
    { file_name: "Contrat_signé.pdf", file_type: "PDF", file_url: "https://example.com/docs/contrat_signe.pdf" },
    { file_name: "Budget_prévisionnel.xlsx", file_type: "Excel", file_url: "https://example.com/docs/budget.xlsx" },
    { file_name: "Notice_PAC.pdf", file_type: "PDF", file_url: "https://example.com/docs/notice_pac.pdf" }
  ]},
  { user_email: "bob@opendevis.com", location_zip: "13008", docs: [
    { file_name: "Diagnostic_énergétique.pdf", file_type: "PDF", file_url: "https://example.com/docs/diag_energie.pdf" },
    { file_name: "Devis_Isolation.pdf", file_type: "PDF", file_url: "https://example.com/docs/devis_isolation.pdf" }
  ]}
]

documents_data.each do |pd|
  user = User.find_by!(email: pd[:user_email])
  project = Project.find_by!(user: user, location_zip: pd[:location_zip])
  pd[:docs].each do |d|
    Document.find_or_create_by!(project: project, file_name: d[:file_name]) do |doc|
      doc.file_type   = d[:file_type]
      doc.file_url    = d[:file_url]
      doc.uploaded_at = Time.current
    end
  end
end

puts "Seeding artisans..."

artisan_data = [
  # Maçonnerie (required by bidding rounds)
  { name: "Marc Dubois", email: "marc.dubois@artisan-maconnerie.fr", company_name: "Dubois Maçonnerie",
    postcode: "75010", phone: "06 11 22 33 44", rating: 4.8, certifications: "RGE, Qualibat",
    categories: ["maconnerie"] },
  { name: "Antoine Vernet", email: "a.vernet@btp-paris.fr", company_name: "BTP Paris Est",
    postcode: "75019", phone: "06 22 33 44 55", rating: 4.5, certifications: "Qualibat",
    categories: ["maconnerie", "carrelage"] },
  { name: "Karim Benali", email: "k.benali@benali-travaux.fr", company_name: "Benali Travaux",
    postcode: "75018", phone: "06 33 44 55 66", rating: 4.2, certifications: nil,
    categories: ["maconnerie"] },
  { name: "Pierre Moreau", email: "pierre.moreau.mac@gmail.com", company_name: nil,
    postcode: "75011", phone: "07 44 55 66 77", rating: 4.6, certifications: "Qualibat",
    categories: ["maconnerie", "isolation"] },
  { name: "Stéphane Girard", email: "s.girard@girard-construction.fr", company_name: "Girard Construction",
    postcode: "92100", phone: "06 55 66 77 88", rating: 4.9, certifications: "RGE, Qualibat",
    categories: ["maconnerie"] },

  # Plomberie
  { name: "Thomas Richard", email: "thomas.richard@aqua-paris.fr", company_name: "AquaParis",
    postcode: "75015", phone: "06 99 00 11 22", rating: 4.9, certifications: "RGE, Qualibat",
    categories: ["plomberie", "chauffage"] },

  # Électricité
  { name: "Sébastien Laurent", email: "s.laurent@electro-paris.fr", company_name: "ElectroParis",
    postcode: "75012", phone: "06 33 55 77 99", rating: 4.8, certifications: "RGE, Qualifelec",
    categories: ["electricite"] },

  # Menuiserie
  { name: "Nicolas Rousseau", email: "n.rousseau@rousseau-menuiserie.fr", company_name: "Rousseau Menuiserie",
    postcode: "75003", phone: "06 88 00 22 44", rating: 4.9, certifications: "Qualibois",
    categories: ["menuiserie"] },

  # Peinture
  { name: "Alexis Thomas", email: "a.thomas@thomas-peinture.fr", company_name: "Thomas Peinture",
    postcode: "75009", phone: "06 22 44 77 00", rating: 4.7, certifications: nil,
    categories: ["peinture"] },

  # Carrelage
  { name: "Roberto Giordano", email: "r.giordano@carrelage-paris.fr", company_name: "Giordano Carrelage",
    postcode: "75011", phone: "06 66 88 11 44", rating: 4.8, certifications: "Qualibat",
    categories: ["carrelage"] },

  # Isolation
  { name: "Vincent Dupont", email: "v.dupont@isolation-pro.fr", company_name: "Isolation Pro",
    postcode: "75005", phone: "06 11 44 88 22", rating: 4.9, certifications: "RGE",
    categories: ["isolation"] },

  # Chauffage
  { name: "Frédéric Marin", email: "f.marin@marin-chauffage.fr", company_name: "Marin Chauffage",
    postcode: "75015", phone: "06 55 88 22 66", rating: 4.8, certifications: "RGE, Qualibat",
    categories: ["chauffage"] }
]

artisan_data.each do |ad|
  artisan = Artisan.find_or_create_by!(email: ad[:email]) do |a|
    a.name         = ad[:name]
    a.company_name = ad[:company_name]
    a.postcode     = ad[:postcode]
    a.phone        = ad[:phone]
    a.rating       = ad[:rating]
    a.certifications = ad[:certifications]
    a.active       = true
    a.password     = "password123"
    a.password_confirmation = "password123"
  end

  artisan.update!(password: "password123", password_confirmation: "password123") if artisan.encrypted_password.blank?

  ad[:categories].each do |slug|
    category = WorkCategory.find_by(slug: slug)
    next unless category

    ArtisanCategory.find_or_create_by!(artisan: artisan, work_category: category)
  end
end

puts "Seeding bidding rounds for Marc Dubois..."

marc   = Artisan.find_by!(email: "marc.dubois@artisan-maconnerie.fr")
antoine = Artisan.find_by!(email: "a.vernet@btp-paris.fr")
maconnerie = WorkCategory.find_by!(slug: "maconnerie")
sika_mat  = Material.find_by!(brand: "Sika",  reference: "SikaTop-107 Seal")
weber_mat = Material.find_by!(brand: "Weber", reference: "weber.rep 767")
parex_mat = Material.find_by!(brand: "Parex", reference: "Parexlanko 260")

bidding_project = Project.find_or_create_by!(user: alice, location_zip: "75010") do |p|
  p.status            = "sent"
  p.room_count        = 3
  p.total_surface_sqm = 72.0
  p.energy_rating     = "E"
end

facade_room = Room.find_or_create_by!(project: bidding_project, name: "Façade et murs porteurs") do |r|
  r.surface_sqm   = 40.0
  r.perimeter_lm  = 26.0
  r.wall_height_m = 3.0
end

WorkItem.find_or_create_by!(room: facade_room, label: "Étanchéité sous-sol") do |item|
  item.work_category    = maconnerie
  item.material         = sika_mat
  item.quantity         = 40
  item.unit             = "kg"
  item.unit_price_exVAT = 3.80
  item.vat_rate         = 10
  item.standing_level   = 2
end

WorkItem.find_or_create_by!(room: facade_room, label: "Rejointoiement façade") do |item|
  item.work_category    = maconnerie
  item.material         = weber_mat
  item.quantity         = 30
  item.unit             = "kg"
  item.unit_price_exVAT = 2.10
  item.vat_rate         = 10
  item.standing_level   = 2
end

WorkItem.find_or_create_by!(room: facade_room, label: "Enduit de ravalement") do |item|
  item.work_category    = maconnerie
  item.material         = parex_mat
  item.quantity         = 60
  item.unit             = "kg"
  item.unit_price_exVAT = 1.85
  item.vat_rate         = 10
  item.standing_level   = 2
end

bidding_project.recompute_totals!

bidding_round = BiddingRound.find_or_create_by!(project: bidding_project) do |br|
  br.standing_level = 2
  br.status         = "sent"
  br.deadline       = 2.weeks.from_now
end

BiddingRequest.find_or_create_by!(bidding_round: bidding_round, work_category: maconnerie, artisan: marc) do |req|
  req.status = "sent"
end

BiddingRequest.find_or_create_by!(bidding_round: bidding_round, work_category: maconnerie, artisan: antoine) do |req|
  req.status = "sent"
end

# Project 2 — Réfection murs humides, Paris 75018
project2 = Project.find_or_create_by!(user: bob, location_zip: "75018") do |p|
  p.status            = "sent"
  p.room_count        = 2
  p.total_surface_sqm = 48.0
  p.energy_rating     = "F"
end

cave_room = Room.find_or_create_by!(project: project2, name: "Cave et sous-sol") do |r|
  r.surface_sqm   = 20.0
  r.perimeter_lm  = 18.0
  r.wall_height_m = 2.2
end

WorkItem.find_or_create_by!(room: cave_room, label: "Traitement humidité murs") do |item|
  item.work_category    = maconnerie
  item.material         = sika_mat
  item.quantity         = 80
  item.unit             = "kg"
  item.unit_price_exVAT = 3.80
  item.vat_rate         = 10
  item.standing_level   = 2
end

WorkItem.find_or_create_by!(room: cave_room, label: "Reprise enduit dégradé") do |item|
  item.work_category    = maconnerie
  item.material         = weber_mat
  item.quantity         = 50
  item.unit             = "kg"
  item.unit_price_exVAT = 2.10
  item.vat_rate         = 10
  item.standing_level   = 2
end

garage_room = Room.find_or_create_by!(project: project2, name: "Mur mitoyen garage") do |r|
  r.surface_sqm   = 12.0
  r.perimeter_lm  = 14.0
  r.wall_height_m = 2.5
end

WorkItem.find_or_create_by!(room: garage_room, label: "Enduit de protection extérieur") do |item|
  item.work_category    = maconnerie
  item.material         = parex_mat
  item.quantity         = 90
  item.unit             = "kg"
  item.unit_price_exVAT = 1.85
  item.vat_rate         = 10
  item.standing_level   = 1
end

project2.recompute_totals!

round2 = BiddingRound.find_or_create_by!(project: project2) do |br|
  br.standing_level = 2
  br.status         = "sent"
  br.deadline       = 10.days.from_now
end

karim = Artisan.find_by!(email: "k.benali@benali-travaux.fr")
BiddingRequest.find_or_create_by!(bidding_round: round2, work_category: maconnerie, artisan: marc) do |req|
  req.status = "sent"
end
BiddingRequest.find_or_create_by!(bidding_round: round2, work_category: maconnerie, artisan: karim) do |req|
  req.status = "sent"
end

# Project 3 — Extension et maçonnerie lourde, Paris 75019
project3 = Project.find_or_create_by!(user: alice, location_zip: "75019") do |p|
  p.status            = "sent"
  p.room_count        = 4
  p.total_surface_sqm = 95.0
  p.energy_rating     = "D"
end

extension_room = Room.find_or_create_by!(project: project3, name: "Extension arrière") do |r|
  r.surface_sqm   = 30.0
  r.perimeter_lm  = 22.0
  r.wall_height_m = 2.7
end

WorkItem.find_or_create_by!(room: extension_room, label: "Montage murs en parpaing") do |item|
  item.work_category    = maconnerie
  item.material         = parex_mat
  item.quantity         = 200
  item.unit             = "kg"
  item.unit_price_exVAT = 1.85
  item.vat_rate         = 10
  item.standing_level   = 3
end

WorkItem.find_or_create_by!(room: extension_room, label: "Enduit finition intérieur") do |item|
  item.work_category    = maconnerie
  item.material         = weber_mat
  item.quantity         = 120
  item.unit             = "kg"
  item.unit_price_exVAT = 2.10
  item.vat_rate         = 10
  item.standing_level   = 3
end

terrace_room = Room.find_or_create_by!(project: project3, name: "Terrasse et margelles") do |r|
  r.surface_sqm   = 18.0
  r.perimeter_lm  = 17.0
  r.wall_height_m = 1.0
end

WorkItem.find_or_create_by!(room: terrace_room, label: "Étanchéité dalle terrasse") do |item|
  item.work_category    = maconnerie
  item.material         = sika_mat
  item.quantity         = 60
  item.unit             = "kg"
  item.unit_price_exVAT = 3.80
  item.vat_rate         = 10
  item.standing_level   = 3
end

project3.recompute_totals!

round3 = BiddingRound.find_or_create_by!(project: project3) do |br|
  br.standing_level = 3
  br.status         = "sent"
  br.deadline       = 3.weeks.from_now
end

pierre = Artisan.find_by!(email: "pierre.moreau.mac@gmail.com")
BiddingRequest.find_or_create_by!(bidding_round: round3, work_category: maconnerie, artisan: marc) do |req|
  req.status = "sent"
end
BiddingRequest.find_or_create_by!(bidding_round: round3, work_category: maconnerie, artisan: pierre) do |req|
  req.status = "sent"
end

# Project 4 — Rénovation complète immeuble Haussmann, Paris 75002
project4 = Project.find_or_create_by!(user: bob, location_zip: "75002") do |p|
  p.status            = "sent"
  p.room_count        = 6
  p.total_surface_sqm = 130.0
  p.energy_rating     = "E"
end

facade2_room = Room.find_or_create_by!(project: project4, name: "Façade côté rue") do |r|
  r.surface_sqm   = 55.0
  r.perimeter_lm  = 30.0
  r.wall_height_m = 4.0
end

WorkItem.find_or_create_by!(room: facade2_room, label: "Ravalement complet façade") do |item|
  item.work_category    = maconnerie
  item.material         = parex_mat
  item.quantity         = 300
  item.unit             = "kg"
  item.unit_price_exVAT = 1.85
  item.vat_rate         = 10
  item.standing_level   = 2
end

WorkItem.find_or_create_by!(room: facade2_room, label: "Injection résine fissures") do |item|
  item.work_category    = maconnerie
  item.material         = sika_mat
  item.quantity         = 25
  item.unit             = "kg"
  item.unit_price_exVAT = 3.80
  item.vat_rate         = 10
  item.standing_level   = 2
end

cour_room = Room.find_or_create_by!(project: project4, name: "Cour intérieure") do |r|
  r.surface_sqm   = 25.0
  r.perimeter_lm  = 20.0
  r.wall_height_m = 3.5
end

WorkItem.find_or_create_by!(room: cour_room, label: "Reprise joints pierre de taille") do |item|
  item.work_category    = maconnerie
  item.material         = weber_mat
  item.quantity         = 80
  item.unit             = "kg"
  item.unit_price_exVAT = 2.10
  item.vat_rate         = 10
  item.standing_level   = 2
end

project4.recompute_totals!

round4 = BiddingRound.find_or_create_by!(project: project4) do |br|
  br.standing_level = 2
  br.status         = "sent"
  br.deadline       = 1.week.from_now
end

stephan = Artisan.find_by!(email: "s.girard@girard-construction.fr")
BiddingRequest.find_or_create_by!(bidding_round: round4, work_category: maconnerie, artisan: marc) do |req|
  req.status = "sent"
end
BiddingRequest.find_or_create_by!(bidding_round: round4, work_category: maconnerie, artisan: stephan) do |req|
  req.status = "sent"
end

puts "Done! #{WorkCategory.count} categories, #{Material.count} materials, #{User.count} users, " \
     "#{Project.count} projects, #{Room.count} rooms, #{WorkItem.count} work items, " \
     "#{Document.count} documents, #{Artisan.count} artisans, #{BiddingRound.count} bidding rounds."
