class DashboardController < ApplicationController

  before_action :authenticate_user!


  def show
    @players = Player.all.sort_by(&:name)
    @games = Game.all
    @chart_data = chart_data(@games.first)
  end
end
