require 'roda'
require 'net/http'
require 'uri'
require 'json'
require 'nokogiri'
require 'socket'

class App < Roda
  plugin :render

  #PRIO_LIST = URI.parse('http://149.56.243.53/systems/prioritylist.php').freeze

  route do |r|
    # GET /
    @players = players
    @queue = query_server('66.70.181.77', 30_120)
    @queue_size = parse_queue(@queue)

    r.root { render :index }
  end

  private

  def twitch_link(id)
    id = steam_hex_to_dec(id).to_s
    return parse_streamer_list[id] if parse_streamer_list.include? id

    nil
  end

  def query_server(ip, port)
    cmd = "\xFF\xFF\xFF\xFFgetinfo f"
    sock = UDPSocket.open
    sock.send(cmd, 0, ip, port)
    resp = if select([sock], nil, nil, 3)
            sock.recvfrom(65_536)
           end
    resp[0] = resp[0][4..-1] if resp
    sock.close
    resp
  end

  def parse_queue(data)
    queue = data[0].split('\\')
    if queue[12][0].eql?('[')
      queue_size = queue[12].split(']')
      return queue_size[0][1..queue_size.length].to_i
    end
    0
  end

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

  def steam_id(steamid)
    steamid_com = steam_hex_to_dec(steamid)
    steam64_to_steam(steamid_com)
  end

  def load_streamer_list
    @load_streamer_list ||= File.read('stream_list.json')
  end

  def parse_streamer_list
    @parse_streamer_list ||= JSON.parse(load_streamer_list)
  end

  def players
    uri = URI.parse('http://66.70.181.77:30120/players.json')
    response = Net::HTTP.get_response(uri)
    list = JSON.parse(response.body)
    names = []
    list.each do |k|
      player = { 'id' => k['id'], 'name' => k['name'],
                 'steamid' => steam_id(k['identifiers'].first),
                 'steamid64' => steam_hex_to_dec(k['identifiers'].first),
                 'ping' => k['ping'], 
                 #'prio' => priority_level(k['identifiers'].first)[0..15],
                 'twitch' => twitch_link(k['identifiers'].first) }
      names << player
    end
    names.sort_by { |k| k['id'] }
  end
end

