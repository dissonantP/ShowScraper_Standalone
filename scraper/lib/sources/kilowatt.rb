require "json"
require "open-uri"

class Kilowatt
  MAIN_URL = "https://kilowattbar.com/events"
  API_BASE_URL = "https://partners-endpoint.dice.fm/api/v2/events"
  PAGE_SIZE = 24

  cattr_accessor :events_limit
  self.events_limit = 200

  def self.run(events_limit: self.events_limit, &foreach_event_blk)
    events = []
    api_key = fetch_api_key
    page = 1

    while events.count < events_limit
      payload = fetch_events_page(page, api_key)
      source_events = payload.fetch("data", [])
      break if source_events.empty?

      source_events.each do |event|
        break if events.count >= events_limit
        result = parse_event_data(event, &foreach_event_blk)
        events << result if result.present?
      end

      break unless payload.fetch("links", {}).key?("next")

      page += 1
    end

    events
  end

  class << self
    private

    def fetch_api_key
      html = URI.open(MAIN_URL, "User-Agent" => "Mozilla/5.0").read
      config_json = html[/DiceEventListWidget\.create\((\{.*?\})\);/m, 1]
      raise "Kilowatt missing Dice widget config" if config_json.blank?

      JSON.parse(config_json).fetch("apiKey")
    rescue JSON::ParserError => e
      raise "Kilowatt invalid Dice widget config: #{e.message}"
    end

    def page_url(page)
      "#{API_BASE_URL}?page[size]=#{PAGE_SIZE}&page[number]=#{page}&types=linkout,event&filter[venues][]=Kilowatt"
    end

    def fetch_events_page(page, api_key)
      body = URI.open(
        page_url(page),
        "User-Agent" => "Mozilla/5.0",
        "x-api-key" => api_key
      ).read

      JSON.parse(body)
    rescue OpenURI::HTTPError => e
      raise "Kilowatt events request failed: #{e.message}"
    rescue JSON::ParserError => e
      raise "Kilowatt invalid events JSON: #{e.message}"
    end

    def parse_event_data(event, &foreach_event_blk)
      title = event["name"].to_s.strip
      return if title.blank?

      {
        url: event["url"].presence || MAIN_URL,
        img: parse_image(event),
        date: DateTime.parse(event.fetch("date")),
        title: title,
        details: ""
      }.
        tap { |data| Utils.print_event_preview(self, data) }.
        tap { |data| foreach_event_blk&.call(data) }
    rescue => e
      ENV["DEBUGGER"] == "true" ? binding.pry : raise
    end

    def parse_image(event)
      event.dig("event_images", "square").presence ||
        event.dig("event_images", "portrait").presence ||
        event.dig("event_images", "landscape").presence ||
        Array(event["images"]).first.to_s
    end
  end
end
