module Webhooks
  class InboundEmailController < ApplicationController
    skip_before_action :authenticate_user!
    skip_before_action :verify_authenticity_token

    def create
      skip_authorization
      ProcessInboundEmailJob.perform_later(params.to_unsafe_h)
      head :ok
    end
  end
end
