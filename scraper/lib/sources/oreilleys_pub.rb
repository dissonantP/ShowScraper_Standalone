require "faraday"
require "json"

class OReilleysPub
  # Eventbrite, "load more" site
  MAIN_URL = "https://www.eventbrite.com/o/oreillys-pub-sf-presents-6806338175"

  cattr_accessor :months_limit, :events_limit
  self.months_limit = 3
  self.events_limit = 200

  def self.run(events_limit: self.events_limit, &foreach_event_blk)
    fetch_events.first(events_limit).filter_map do |event|
      parse_event_data(event, &foreach_event_blk)
    end.uniq { |e| [e[:date].strftime("%m/%d/%Y"), e[:title]] }.sort_by { |e| e[:date] }
  end

  class << self
    private

    def fetch_events
      html = Faraday.get(MAIN_URL) do |req|
        req.options.timeout = 20
        req.options.open_timeout = 10
        req.headers["user-agent"] = "Mozilla/5.0"
      end.body

      json = html[/<script id="__NEXT_DATA__" type="application\/json">(.*?)<\/script>/m, 1]
      raise "OReilleysPub missing __NEXT_DATA__ payload" if json.blank?

      JSON.parse(json).dig("props", "pageProps", "upcomingEvents") || []
    end

    def parse_event_data(event, &foreach_event_blk)
      title = event["name"].to_s.strip
      date = parse_date(event)
      return if title.blank?
      return if date.blank?

      {
        url: event["url"],
        img: event.dig("image", "url") || "https://img.evbuc.com/https%3A%2F%2Fcdn.evbuc.com%2Fimages%2F508879929%2F78654724783%2F1%2Foriginal.20230505-225547?h=230&w=460&auto=format%2Ccompress&q=75&sharp=10&rect=0%2C152%2C1242%2C621&s=39c1c2c43fbea1958ab34d2b46660fcc",
        date: date,
        title: title,
        details: ""
      }.
        tap { |data| Utils.print_event_preview(self, data) }.
        tap { |data| foreach_event_blk&.call(data) }
    rescue => e
      ENV["DEBUGGER"] == "true" ? binding.pry : raise
    end

    def parse_date(event)
      date = DateTime.parse([event["start_date"], event["start_time"]].join(" "))
      date += 1.year while date < (DateTime.now - 30.days)
      date
    end

  end
end
