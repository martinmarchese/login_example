class DashboardController < ApplicationController
  before_action -> { rodauth.require_authentication }

  def index
    @account = current_account
  end
end
