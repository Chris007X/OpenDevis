class EstimationPdfGenerator
  STANDING_LABELS = { 1 => "Éco", 2 => "Standard", 3 => "Premium" }.freeze
  PROJECT_TYPE_LABELS = {
    "renovation" => "Rénovation",
    "construction" => "Construction neuve",
    "extension" => "Extension"
  }.freeze

  def initialize(project, standing:, rooms:, total_ht:, total_ttc:, categories_data:)
    @project = project
    @standing = standing
    @rooms = rooms
    @total_ht = total_ht
    @total_ttc = total_ttc
    @categories_data = categories_data
  end

  FONT_DIR = Rails.root.join("app/assets/fonts")

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def generate
    pdf = Prawn::Document.new(page_size: "A4", margin: [ 40, 40, 40, 40 ])
    pdf.font_families.update(
      "DejaVu" => {
        normal: FONT_DIR.join("DejaVuSans.ttf").to_s,
        bold: FONT_DIR.join("DejaVuSans-Bold.ttf").to_s
      }
    )
    pdf.font "DejaVu"

    render_header(pdf)
    render_project_info(pdf)
    render_totals(pdf)

    if @categories_data.any?
      render_categories(pdf)
      render_grand_total(pdf)
    else
      pdf.move_down 20
      pdf.text "Aucun poste pour ce niveau de standing.", size: 11, color: "9B9588", style: :italic
    end

    render_footer(pdf)
    pdf.render
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  private

  def render_header(pdf)
    pdf.formatted_text [
      { text: "Open", size: 18, styles: [:bold], color: "2C2A25" },
      { text: "Devis", size: 18, styles: [:bold], color: "2563eb" }
    ]
    pdf.move_down 12
    pdf.text "ESTIMATION DE TRAVAUX", size: 20, style: :bold
    pdf.move_down 20
  end

  def render_project_info(pdf)
    pdf.text @project.name.presence || "Projet sans nom", size: 14, style: :bold
    info = []
    info << (@project.location_zip.presence || "N/A")
    info << "#{@project.total_surface_sqm.to_i} m²" if @project.total_surface_sqm
    info << "#{@project.room_count} pièces" if @project.room_count
    info << "DPE #{@project.energy_rating}" if @project.energy_rating.present?
    info << PROJECT_TYPE_LABELS[@project.project_type] || @project.project_type
    pdf.text info.join(" · "), size: 10, color: "666666"
    pdf.move_down 6
    pdf.text "Standing : #{STANDING_LABELS[@standing]}", size: 10, style: :bold, color: "2563eb"
    pdf.move_down 20
  end

  def render_totals(pdf)
    pdf.text "Total HT : #{format_price(@total_ht)} €", size: 16, style: :bold
    pdf.move_down 4
    pdf.text "Total TTC : #{format_price(@total_ttc)} €", size: 14, color: "4A4640"
    pdf.move_down 24
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def render_categories(pdf)
    pdf.text "Détail par catégorie", size: 14, style: :bold
    pdf.move_down 12

    work_items_by_category = build_work_items_by_category

    @categories_data.each do |data|
      cat = data[:category]
      cat_name = cat&.name || "Autre"
      items = work_items_by_category[cat&.id] || []

      pdf.text cat_name, size: 11, style: :bold
      pdf.move_down 6

      table_data = [[ "Poste", "Qté", "Unité", "Prix unit. HT", "TVA %", "Total HT" ]]
      items.each do |item|
        line_total = (item.quantity || 0) * (item.unit_price_exVAT || 0)
        table_data << [
          item.label,
          item.quantity.to_s,
          item.unit,
          "#{format_price(item.unit_price_exVAT)} €",
          "#{item.vat_rate}%",
          "#{format_price(line_total)} €"
        ]
      end
      table_data << [ { content: "Sous-total #{cat_name}", colspan: 5, font_style: :bold },
                       { content: "#{format_price(data[:total])} €", font_style: :bold } ]

      pdf.table(table_data, header: true, width: pdf.bounds.width, cell_style: { size: 9 }) do |t|
        t.row(0).font_style = :bold
        t.row(0).background_color = "2C2A25"
        t.row(0).text_color = "FFFFFF"
        t.columns(1).align = :center
        t.columns(2).align = :center
        t.columns(3..5).align = :right
        t.row(-1).background_color = "F5F3EF"
      end
      pdf.move_down 14
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  def render_grand_total(pdf)
    pdf.move_down 6
    total_table = [
      [ { content: "TOTAL HT", font_style: :bold }, { content: "#{format_price(@total_ht)} €", font_style: :bold } ],
      [ { content: "TOTAL TTC", font_style: :bold }, { content: "#{format_price(@total_ttc)} €", font_style: :bold } ]
    ]
    pdf.table(total_table, width: pdf.bounds.width, cell_style: { size: 11 }) do |t|
      t.columns(1).align = :right
      t.row(0).background_color = "2C2A25"
      t.row(0).text_color = "FFFFFF"
      t.row(1).background_color = "2563eb"
      t.row(1).text_color = "FFFFFF"
    end
  end

  def render_footer(pdf)
    pdf.move_down 30
    pdf.text "Généré par OpenDevis le #{I18n.l(Date.current, format: :long)}",
             size: 8, color: "999999"
  end

  def build_work_items_by_category
    items = @rooms.flat_map { |r| r.work_items.select { |i| i.standing_level == @standing } }
    items.group_by(&:work_category_id)
  end

  def format_price(amount)
    return "0,00" unless amount
    whole, decimal = format("%.2f", amount.to_f).split(".")
    "#{whole.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1 ')},#{decimal}"
  end
end
