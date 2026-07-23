require "json"
require "open-uri"

class TheLab
  MAIN_URL = "https://www.thelab.org/projects"
  JSON_URL = "#{MAIN_URL}?format=json"
  TIME_ZONE = "America/Los_Angeles"

  cattr_accessor :events_limit
  self.events_limit = 200

  def self.run(events_limit: self.events_limit, &foreach_event_blk)
    fetch_events.first(events_limit).map do |event|
      parse_event_data(event, &foreach_event_blk)
    end.compact
  end

  class << self
    private

    def fetch_events
      data = JSON.parse(URI.open(JSON_URL).read)
      data.fetch("upcoming", []).select do |event|
        event.fetch("categories", []).include?("Concert")
      end
    end

    def parse_event_data(event, &foreach_event_blk)
      date = parse_date(event["startDate"])
      return if date < DateTime.now.in_time_zone(TIME_ZONE).to_datetime

      {
        url: absolute_url(event["fullUrl"]),
        img: event["assetUrl"].to_s,
        date: date,
        title: event["title"].to_s.strip,
        details: ""
      }.
        tap { |data| Utils.print_event_preview(self, data) }.
        tap { |data| foreach_event_blk&.call(data) }
    rescue => e
      ENV["DEBUGGER"] == "true" ? binding.pry : raise
    end

    def parse_date(value)
      Time.at(value.to_i / 1000.0).in_time_zone(TIME_ZONE).to_datetime
    end

    def absolute_url(value)
      URI.join(MAIN_URL, value.to_s).to_s
    end
  end
end
