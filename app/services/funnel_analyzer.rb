# FunnelAnalyzer — queries analytics_funnels for a named funnel and returns
# structured data suitable for dashboard rendering.
#
# Usage:
#   analyzer = FunnelAnalyzer.new("wizard_to_estimate")
#   analyzer.steps           # step definitions
#   analyzer.report(days: 30) # { steps: [...], overall_conversion: 42.0, total_started: 120 }
class FunnelAnalyzer
  FUNNELS = {
    "wizard_to_estimate" => [
      { number: 1, name: "property_info",      label: "Infos du bien" },
      { number: 2, name: "renovation_type",    label: "Type de rénovation" },
      { number: 3, name: "work_categories",    label: "Travaux souhaités" },
      { number: 4, name: "recap_standing",     label: "Récapitulatif" },
      { number: 5, name: "estimate_generated", label: "Estimation générée" }
    ],
    "bidding_to_contract" => [
      { number: 1, name: "configure_bid",      label: "Config. appel d'offres" },
      { number: 2, name: "bid_configured",     label: "Offre configurée" },
      { number: 3, name: "select_artisans",    label: "Artisans sélectionnés" },
      { number: 4, name: "requests_sent",      label: "Demandes envoyées" },
      { number: 5, name: "review_responses",   label: "Réponses examinées" },
      { number: 6, name: "contract_confirmed", label: "Contrat confirmé" }
    ]
  }.freeze

  def self.all_names = FUNNELS.keys

  def initialize(funnel_name)
    @funnel_name = funnel_name
    @steps       = FUNNELS.fetch(funnel_name, [])
  end

  attr_reader :funnel_name, :steps

  # Returns a hash with:
  #   :total_started   — unique sessions/users who hit step 1
  #   :overall_conversion — % who completed the final step
  #   :steps           — array of step hashes with :entered, :dropped, :rate, :drop_rate
  def report(days: 30)
    base = AnalyticsFunnel.by_funnel(@funnel_name).recent(days)

    # Count distinct sessions per step
    entered_by_step = base.group(:step_number).distinct.count(:session_id)
    total_started   = entered_by_step[1] || 0

    step_reports = @steps.map do |step_def|
      step_num   = step_def[:number]
      entered    = entered_by_step[step_num] || 0
      prev_step  = @steps.find { |s| s[:number] == step_num - 1 }
      prev_count = prev_step ? (entered_by_step[prev_step[:number]] || 0) : entered

      drop_rate = prev_count.zero? ? 0.0 : ((prev_count - entered).to_f / prev_count * 100).round(1)
      rate      = total_started.zero? ? 0.0 : (entered.to_f / total_started * 100).round(1)

      step_def.merge(
        entered:   entered,
        dropped:   [ prev_count - entered, 0 ].max,
        rate:      rate,       # % of step-1 users who reached this step
        drop_rate: drop_rate   # % drop from previous step to this one
      )
    end

    last_step_entered = entered_by_step[@steps.last&.fetch(:number, 0)] || 0
    overall = total_started.zero? ? 0.0 : (last_step_entered.to_f / total_started * 100).round(1)

    {
      funnel_name:         @funnel_name,
      total_started:       total_started,
      overall_conversion:  overall,
      steps:               step_reports
    }
  end
end
