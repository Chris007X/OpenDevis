# Be sure to restart your server when you modify this file.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data, "https://fonts.gstatic.com"
    policy.img_src     :self, :data, :https, :blob      # :https pour og:image importées
    policy.object_src  :none
    policy.script_src  :self, :unsafe_inline            # requis importmap + Stimulus inline
    policy.style_src   :self, :unsafe_inline, "https://fonts.googleapis.com"  # requis Bootstrap + _od_styles inline + Google Fonts
    policy.connect_src :self,
                       "https://geo.api.gouv.fr",                       # city-autocomplete
                       "https://models.inference.ai.azure.com"          # LLM API (GitHub Models)
    policy.frame_ancestors :none
  end
end
