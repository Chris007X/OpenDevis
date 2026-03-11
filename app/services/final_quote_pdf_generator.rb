class FinalQuotePdfGenerator
  def initialize(bidding_round)
    @bidding_round = bidding_round
    @project = bidding_round.project
    @selections = bidding_round.final_selections.includes(bidding_request: %i[artisan work_category])
  end

  # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
  def generate
    pdf = Prawn::Document.new(page_size: "A4", margin: [40, 40, 40, 40])

    # Header
    pdf.text "DEVIS FINALISÉ", size: 20, style: :bold
    pdf.move_down 6
    pdf.text "OpenDevis", size: 12, color: "9B9588"
    pdf.move_down 20

    # Project info
    pdf.text "Projet : #{@project.location_zip}", size: 14, style: :bold
    info = []
    info << "Surface : #{@project.total_surface_sqm.to_i} m²" if @project.total_surface_sqm
    info << "Pièces : #{@project.room_count}" if @project.room_count
    info << "Standing : #{@bidding_round.standing_label}"
    pdf.text info.join(" · "), size: 10, color: "666666"
    pdf.move_down 20

    # Total
    total = @selections.sum { |s| s.bidding_request.price_total.to_f }
    pdf.text "Total artisans HT : #{format_price(total)} €", size: 16, style: :bold
    pdf.move_down 20

    # Table
    pdf.text "Détail par catégorie", size: 14, style: :bold
    pdf.move_down 10

    table_data = [["Catégorie", "Artisan", "Note", "Prix HT"]]
    @selections.each do |selection|
      req = selection.bidding_request
      table_data << [
        req.work_category.name,
        "#{req.artisan.name}#{" (#{req.artisan.company_name})" if req.artisan.company_name.present?}",
        req.artisan.rating.present? ? "#{req.artisan.star_rating}/5" : "—",
        "#{format_price(req.price_total)} €"
      ]
    end

    pdf.table(table_data, header: true, width: pdf.bounds.width) do |t|
      t.row(0).font_style = :bold
      t.row(0).background_color = "2C2A25"
      t.row(0).text_color = "FFFFFF"
      t.columns(3).align = :right
    end

    pdf.move_down 30

    # Artisan contacts
    pdf.text "Coordonnées des artisans", size: 14, style: :bold
    pdf.move_down 10

    @selections.each do |selection|
      artisan = selection.bidding_request.artisan
      pdf.text "#{artisan.name}#{" — #{artisan.company_name}" if artisan.company_name.present?}", style: :bold,
                                                                                                  size: 10
      pdf.text "Email : #{artisan.email}  ·  Tél : #{artisan.phone.presence || 'N/A'}", size: 9, color: "666666"
      pdf.move_down 8
    end

    # Footer
    pdf.move_down 20
    pdf.text "Généré par OpenDevis le #{I18n.l(Time.current, format: :long)}", size: 8, color: "999999"

    pdf.render
  end
  # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity

  private

  def format_price(amount)
    return "0,00" unless amount

    whole, decimal = format("%.2f", amount.to_f).split(".")
    "#{whole.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1 ')},#{decimal}"
  end
end
