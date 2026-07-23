require "cgi"
require "json"
require "nokogiri"
require "open-uri"

class F8
  MAIN_URL = "https://www.feightsf.com/"
  EVENTS_URL = "#{MAIN_URL}new-events"
  FEED_URL = "#{EVENTS_URL}?format=json"
  TIME_ZONE = "America/Los_Angeles"

  cattr_accessor :events_limit
  self.events_limit = 200

  def self.run(events_limit: self.events_limit, &foreach_event_blk)
    events = []

    fetch_events.each do |event|
      break if events.count >= events_limit
      result = parse_event_data(event, &foreach_event_blk)
      events << result if result
    end

    events
  end

  class << self
    private

    def fetch_events
      JSON.parse(URI.open(FEED_URL).read).fetch("upcoming", [])
    rescue JSON::ParserError => e
      raise "F8 invalid events JSON: #{e.message}"
    end

    def parse_event_data(event, &foreach_event_blk)
      title = parse_title(event)
      return if title.blank?

      {
        url: event_url(event),
        img: event["assetUrl"].to_s,
        date: parse_date(event),
        title: title,
        details: ""
      }.
        tap { |data| Utils.print_event_preview(self, data) }.
        tap { |data| foreach_event_blk&.call(data) }
    rescue => e
      ENV["DEBUGGER"] == "true" ? binding.pry : raise
    end

    def event_url(event)
      path = event["fullUrl"].to_s
      return EVENTS_URL if path.blank?
      return "#{MAIN_URL.delete_suffix("/")}#{path}" if path.start_with?("/")
      path
    end

    def parse_date(event)
      start_ms = event["startDate"] || event.dig("structuredContent", "startDate")
      raise "F8 missing startDate for #{event["title"]}" unless start_ms

      Time.at(start_ms.to_f / 1000).in_time_zone(TIME_ZONE).to_datetime
    end

    def parse_title(event)
      title = normalize_text(event["title"])
      billing_lines = parse_billing_lines(event["body"])
      ([title] + billing_lines).reject(&:blank?).uniq.join(" - ")
    end

    def parse_billing_lines(html)
      doc = Nokogiri::HTML.fragment(html.to_s)
      doc.css("br").each { |br| br.replace("\n") }

      doc.css(".sqs-html-content p").flat_map { |node| node.text.split(/\n+/) }.
        map { |line| normalize_text(line) }.
        reject(&:blank?).
        reject { |line| separator_line?(line) }.
        take_while { |line| billing_line?(line) }.
        reject { |line| line.length > 140 || line.end_with?("...") }.
        first(8)
    end

    def billing_line?(line)
      line !~ /\A(?:[-_]+|free\b|tickets?\b|rsvp\b|\$\d|champagne\b|2 rooms\b|2 full bars\b|21\+|please note\b|f8 seeks\b|dance family\b|set times\b|early bird\b|tier \d\b)/i
    end

    def separator_line?(line)
      line.gsub(/[[:punct:]\s]/, "").blank?
    end

    def normalize_text(text)
      CGI.unescapeHTML(text.to_s).gsub(/[[:space:]]+/, " ").strip
    end
  end
end
