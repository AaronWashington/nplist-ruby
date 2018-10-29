require 'roda'
require 'net/http'
require 'uri'
require 'json'

class App < Roda
  plugin :render

  route do |r|
    # GET /
    @players = players
  
    r.root { render :index }
  end

  private

  def players
    uri = URI.parse('http://66.70.181.77:30110/players.json')
    response = Net::HTTP.get_response(uri)
    list = JSON.parse(response.body)
    names = []
    list.each do |k|
      player = { 'id' => k['id'], 'name' => k['name'] }
      names.push(player)
    end
    names
  end
end
