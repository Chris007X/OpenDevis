# db/seeds/reference_prices.rb
# v2: Single set of Standard prices — Éco/Premium derived via standing coefficients
ReferencePrice.delete_all

def seed_category(slug, items)
  items.each_with_index do |item, idx|
    ReferencePrice.create!(
      category_slug: slug, label: item[:label], unit: item[:unit],
      supply_price_exVAT: item[:supply], labor_price_exVAT: item[:labor],
      vat_rate: item[:vat] || 10,
      quantity_formula: item[:formula] || "surface",
      applicable_rooms: item[:rooms], sort_order: idx
    )
  end
end

# ── Démolition & maçonnerie ──────────────────────────────────────────────────
seed_category("demolition_maconnerie", [
  { label: "Démolition cloison légère (placo)", unit: "m2", supply: 0.50, labor: 12.00, formula: "wall_surface" },
  { label: "Démolition cloison maçonnée (brique/parpaing)", unit: "m2", supply: 1.00, labor: 25.00, formula: "wall_surface" },
  { label: "Montage cloison placo sur rail", unit: "m2", supply: 15.00, labor: 28.00, formula: "wall_surface" },
  { label: "Enduit de lissage murs", unit: "m2", supply: 3.50, labor: 18.00, formula: "wall_surface" },
  { label: "Évacuation gravats (benne)", unit: "m2", supply: 3.00, labor: 5.00, formula: "surface" }
])

# ── Isolation ────────────────────────────────────────────────────────────────
seed_category("isolation", [
  { label: "Isolation murs laine de roche 140mm (R=4.0)", unit: "m2", supply: 14.00, labor: 22.00, vat: 5, formula: "wall_surface" },
  { label: "Isolation plafond laine de roche + BA13", unit: "m2", supply: 18.00, labor: 25.00, vat: 5, formula: "ceiling" },
  { label: "Isolation sol polyuréthane 60mm", unit: "m2", supply: 12.00, labor: 20.00, vat: 5, formula: "surface" }
])

# ── Fenêtres ─────────────────────────────────────────────────────────────────
seed_category("fenetres", [
  { label: "Fenêtre PVC haute isolation Uw≤1.3 (L120×H135)", unit: "pce", supply: 400.00, labor: 200.00, vat: 5, formula: "fixed:2" },
  { label: "Porte-fenêtre PVC haute isolation (L140×H215)", unit: "pce", supply: 550.00, labor: 250.00, vat: 5, formula: "fixed:1" },
  { label: "Volet roulant électrique", unit: "pce", supply: 280.00, labor: 150.00, vat: 5, formula: "fixed:2" }
])

# ── Toiture & étanchéité ─────────────────────────────────────────────────────
seed_category("toiture", [
  { label: "Réfection couverture tuiles mécaniques", unit: "m2", supply: 25.00, labor: 45.00, formula: "surface" },
  { label: "Zinguerie (gouttières, descentes)", unit: "ml", supply: 18.00, labor: 25.00, formula: "perimeter" },
  { label: "Traitement et renfort charpente", unit: "m2", supply: 8.00, labor: 18.00, formula: "surface" }
])

# ── Électricité ──────────────────────────────────────────────────────────────
seed_category("electricite", [
  { label: "Tableau électrique NF C 15-100 complet", unit: "pce", supply: 350.00, labor: 400.00, formula: "fixed:1" },
  { label: "Prises + interrupteurs encastrés", unit: "pce", supply: 12.00, labor: 35.00, formula: "per_sqm:0.4" },
  { label: "Points lumineux (spots encastrés LED)", unit: "pce", supply: 25.00, labor: 40.00, formula: "per_sqm:0.3" },
  { label: "Câblage réseau RJ45 / multimédia", unit: "pce", supply: 20.00, labor: 45.00, formula: "fixed:2" }
])

# ── Plomberie ────────────────────────────────────────────────────────────────
seed_category("plomberie", [
  { label: "Reprise alimentation eau chaude/froide (PER)", unit: "ml", supply: 6.00, labor: 30.00, formula: "per_lm:0.5", rooms: "Cuisine,SDB,WC" },
  { label: "Reprise évacuations PVC complètes", unit: "ml", supply: 10.00, labor: 35.00, formula: "per_lm:0.4", rooms: "Cuisine,SDB,WC" },
  { label: "Mitigeur thermostatique (Grohe/Hansgrohe)", unit: "pce", supply: 150.00, labor: 65.00, formula: "fixed:1", rooms: "SDB" },
  { label: "Création arrivée d'eau lave-vaisselle", unit: "pce", supply: 20.00, labor: 80.00, formula: "fixed:1", rooms: "Cuisine" }
])

# ── Ventilation & chauffage ──────────────────────────────────────────────────
seed_category("ventilation_chauffage", [
  { label: "VMC simple flux hygroréglable type B", unit: "pce", supply: 350.00, labor: 400.00, vat: 5, formula: "fixed:1" },
  { label: "Chaudière gaz condensation (25kW)", unit: "pce", supply: 1800.00, labor: 800.00, vat: 5, formula: "fixed:1" },
  { label: "Radiateur acier design (type 22, 1000W)", unit: "pce", supply: 220.00, labor: 120.00, vat: 5, formula: "per_sqm:0.07" },
  { label: "Thermostat programmable connecté", unit: "pce", supply: 180.00, labor: 100.00, vat: 5, formula: "fixed:1" }
])

# ── Menuiseries intérieures ──────────────────────────────────────────────────
seed_category("menuiseries_interieures", [
  { label: "Porte intérieure postformée + huisserie bois", unit: "pce", supply: 150.00, labor: 110.00, formula: "fixed:1" },
  { label: "Placard coulissant aménagé (L180cm)", unit: "pce", supply: 450.00, labor: 250.00, formula: "fixed:1", rooms: "Chambre,Entrée" },
  { label: "Plinthe chêne massif 10cm", unit: "ml", supply: 8.00, labor: 8.00, formula: "perimeter" },
  { label: "Parquet contrecollé chêne clipsable", unit: "m2", supply: 30.00, labor: 22.00, formula: "surface" }
])

# ── Peintures ────────────────────────────────────────────────────────────────
seed_category("peintures", [
  { label: "Préparation murs (enduit + ponçage) + 2 couches", unit: "m2", supply: 4.00, labor: 18.00, formula: "wall_surface" },
  { label: "Peinture plafond 2 couches blanc mat", unit: "m2", supply: 3.00, labor: 16.00, formula: "ceiling" },
  { label: "Peinture boiseries (portes, plinthes) laque", unit: "ml", supply: 3.00, labor: 12.00, formula: "perimeter" }
])

# ── Cuisine ──────────────────────────────────────────────────────────────────
seed_category("cuisine", [
  { label: "Cuisine équipée milieu de gamme (meubles + plan stratifié + électroménager)", unit: "forfait", supply: 4500.00, labor: 1500.00, formula: "fixed:1", rooms: "Cuisine" },
  { label: "Crédence carrelage métro ou faïence", unit: "m2", supply: 25.00, labor: 35.00, formula: "fixed:4", rooms: "Cuisine" },
  { label: "Évier granit + mitigeur douchette", unit: "pce", supply: 200.00, labor: 100.00, formula: "fixed:1", rooms: "Cuisine" }
])

# ── Salle de bain & WC ──────────────────────────────────────────────────────
seed_category("salle_de_bain_wc", [
  { label: "Douche italienne receveur extra-plat + paroi fixe", unit: "pce", supply: 500.00, labor: 500.00, formula: "fixed:1", rooms: "SDB" },
  { label: "WC suspendu + bâti-support", unit: "pce", supply: 300.00, labor: 250.00, formula: "fixed:1", rooms: "SDB,WC" },
  { label: "Meuble vasque 80cm + miroir éclairé", unit: "pce", supply: 450.00, labor: 200.00, formula: "fixed:1", rooms: "SDB" },
  { label: "Carrelage grès cérame sol + murs zone humide", unit: "m2", supply: 30.00, labor: 40.00, formula: "fixed:8", rooms: "SDB" },
  { label: "Sèche-serviettes mixte 750W", unit: "pce", supply: 180.00, labor: 120.00, formula: "fixed:1", rooms: "SDB" }
])
