require 'json'
require 'open-uri'
require 'time'

class BlackCatJazzSupperClub
  MAIN_URL = "https://blackcatsf.turntabletickets.com/"
  API_URL = "#{MAIN_URL}api/performance/"
  TIME_ZONE = "America/Los_Angeles"

  cattr_accessor :events_limit
  self.events_limit = 200

  def self.run(events_limit: self.events_limit, &foreach_event_blk)
    events = fetch_performances
    events.first(events_limit).map do |event|
      parse_event_data(event, &foreach_event_blk)
    end.compact
  end

  class << self
    private

    def fetch_performances
      start_date = Time.find_zone!(TIME_ZONE).today.iso8601
      url = "#{API_URL}?start_date=#{start_date}&pagination=false"
      JSON.parse(URI.open(url).read).fetch("results").sort_by { |event| event.fetch("datetime") }
    end

    def parse_event_data(event, &foreach_event_blk)
      show = event.fetch("show")
      data = {
        url: event_url(event),
        img: image_url(show),
        date: parse_date(event),
        title: show.fetch("name").strip,
        details: ""
      }

      data.
        tap { |event_data| Utils.print_event_preview(self, event_data) }.
        tap { |event_data| foreach_event_blk&.call(event_data) }
    rescue => e
      ENV["DEBUGGER"] == "true" ? binding.pry : raise
    end

    def event_url(event)
      "#{MAIN_URL}shows/#{event.fetch("show_id")}/?date=#{performance_time(event).to_date.iso8601}"
    end

    def image_url(show)
      show.dig("srcset", "rectLg", "src") || show["image"] || ""
    end

    def parse_date(event)
      performance_time(event).to_datetime
    end

    def performance_time(event)
      Time.iso8601(event.fetch("datetime")).in_time_zone(TIME_ZONE)
    end
  end
end
