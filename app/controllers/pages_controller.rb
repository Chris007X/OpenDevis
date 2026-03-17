class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[home cookie_policy]

  def home
  end

  def cookie_policy
  end
end
