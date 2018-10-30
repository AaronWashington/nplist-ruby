require 'roda'
require 'net/http'
require 'uri'
require 'json'
require 'nokogiri'

class App < Roda
  plugin :render

  PRIO_LIST = URI.parse('http://koil.tv/systems/prioritylist.php').freeze

  route do |r|
    # GET /
    @players = players
    r.root { render :index }
  end

  private

  def parese_data(input, steamid)
    table = input.search('table')

    table.search('tr').drop(1).each do |tr|
      tds = tr.search('td')
      return tds[2].text if tds[1].text.eql?(steamid)
    end
    0
  end

  def priority_data
    response ||= Net::HTTP.get_response(PRIO_LIST)
    Nokogiri::HTML.parse(response.body)
  end

  def priority_level(steamid) 
    steamid_com = steam_hex_to_dec(steamid)
    steamid_legacy = steam64_to_steam(steamid_com)
    @doc ||= priority_data
    level = parese_data(@doc, steamid_legacy)
    '⭐' * level.to_i
  end

  def steam_hex_to_dec(input)
    input.slice!('steam:')
    input.to_i(16)
  end

  def steam64_to_steam(input)
    steam_id = (input - 76_561_197_960_265_728) / 2
    "STEAM_0:#{input % 2}:#{steam_id}"
  end

  def players
    uri = URI.parse('http://66.70.181.77:30110/players.json')
    response = Net::HTTP.get_response(uri)
    list = JSON.parse(response.body)
    names = []
    list.each do |k|
      player = { 'id' => k['id'], 'name' => k['name'], 'steamid64' => steam_hex_to_dec(k['identifiers'].first), 'prio' => priority_level(k['identifiers'].first)[0..15]}
 
      names << player
    end
    names
  end
end
