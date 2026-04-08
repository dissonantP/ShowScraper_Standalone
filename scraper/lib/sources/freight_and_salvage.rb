require "faraday"

class FreightAndSalvage
  MAIN_URL = "https://thefreight.org/shows/"
  JAMBASE_URL = "https://www.jambase.com/venue/the-freight-berkeley-ca"
  MIRROR_PREFIX = "https://r.jina.ai/http://"

  cattr_accessor :events_limit, :load_time
  self.events_limit = 200
  self.load_time = 2

  def self.run(events_limit: self.events_limit, &foreach_event_blk)
    fetch_events.first(events_limit).map do |event|
      parse_event_data(event, &foreach_event_blk)
    end.compact
  end

  class << self
    private

    def fetch_events
      lines = fetch_markdown.lines.map(&:strip)
      current_date = nil

      lines.filter_map do |line|
        date_match = line.match(/\A\*\s+([A-Z][a-z]{2}\s+\d{1,2},\s+\d{4})\z/)
        if date_match
          current_date = DateTime.parse(date_match[1])
          next
        end

        next unless current_date

        match = line.match(%r{\A\*\s+\[!\[Image \d+:? ?([^\]]*)\]\((https://[^)]+)\)\]\((https://www\.jambase\.com/show/[^)]+)\)(?:\s+####\s+\[([^\]]+)\]\([^)]+\))?})
        next unless match

        alt_title, img, url, linked_title = match.captures
        title = linked_title.presence || alt_title.presence || "Freight Event"

        {
          date: current_date,
          img: img,
          title: title,
          url: url,
          details: ""
        }
      end
    end

    def fetch_markdown
      response = Faraday.get("#{MIRROR_PREFIX}#{JAMBASE_URL}") do |req|
        req.options.timeout = 20
        req.options.open_timeout = 10
        req.headers["accept"] = "text/plain, text/markdown;q=0.9, */*;q=0.8"
      end

      unless response.success?
        raise "FreightAndSalvage mirror returned #{response.status}"
      end

      response.body
    end

    def parse_event_data(event, &foreach_event_blk)
      {
        date: event[:date],
        img: event[:img],
        title: event[:title],
        url: event[:url],
        details: event[:details]
      }.
        tap { |data| Utils.print_event_preview(self, data) }.
        tap { |data| foreach_event_blk&.call(data) }
    rescue => e
      ENV["DEBUGGER"] == "true" ? binding.pry : raise
    end
  end
end
