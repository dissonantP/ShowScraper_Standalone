require "cgi"
require "nokogiri"
require "open-uri"

class MabuhayGardens
  MAIN_URL = "https://themab.org/"
  TIME_ZONE = "America/Los_Angeles"

  cattr_accessor :events_limit
  self.events_limit = 200

  def self.run(events_limit: self.events_limit, &foreach_event_blk)
    get_events.first(events_limit).filter_map do |event|
      parse_event_data(event, &foreach_event_blk)
    end
  end

  class << self
    private

    def get_events
      html = URI.open(MAIN_URL, "User-Agent" => "Mozilla/5.0").read
      doc = Nokogiri::HTML(html)
      doc.css("#mab-events-display .mab-coverflow > li[data-date].tag-live-music").
        reject { |event| event["class"].to_s.include?("status-past") }.
        select { |event| Date.iso8601(event["data-date"]) >= Time.find_zone!(TIME_ZONE).today }
    end

    def parse_event_data(event, &foreach_event_blk)
      data = {
        url: parse_url(event),
        img: normalize_url(event.at_css("article > img[src]")&.[]("src")),
        date: parse_date(event),
        title: parse_title(event),
        details: ""
      }

      return if data[:title].blank?

      data.
        tap { |event_data| Utils.print_event_preview(self, event_data) }.
        tap { |event_data| foreach_event_blk&.call(event_data) }
    rescue => e
      ENV["DEBUGGER"] == "true" ? binding.pry : raise
    end

    def parse_url(event)
      normalize_url(event.at_css("a.mab-outline-btn[href]")&.[]("href")) || MAIN_URL
    end

    def parse_title(event)
      title = normalize_text(event.at_css("h3")&.text)
      support = parse_support_billing(event, title)

      [title, support].reject(&:blank?).join(", ")
    end

    def parse_support_billing(event, title)
      support = [subtitle_billing(event), details_billing(event)].reject(&:blank?).join(", ")
      support = body_billing(event) if support.blank?

      support.
        split(/\s*,\s*/).
        map { |artist| artist.sub(/\Aand\s+/i, "").strip }.
        reject { |artist| artist.blank? || artist.casecmp?(title) }.
        uniq { |artist| artist.downcase }.
        join(", ")
    end

    def subtitle_billing(event)
      subtitle = normalize_text(event.at_css(".mab-event-subtitle")&.text)
      return "" if subtitle.blank?
      return "" if subtitle.include?("//")
      return "" if subtitle.match?(/\b(?:mab|downstairs|upstairs|broadway|doors?|show|music|live|21\+|all ages|pm|am|takeover|ballroom)\b/i)

      split_billing(subtitle)
    end

    def details_billing(event)
      details = event.at_css("details")
      return "" unless normalize_text(details&.at_css("summary")&.text).match?(/lineup/i)

      html = details&.at_css("div")&.inner_html.to_s
      lines = html.split(/<br\s*\/?>/i).map { |line| normalize_text(line) }.reject(&:blank?)
      text = lines.join(" ")
      return "" if text.blank?

      timed_artists = lines.map { |line| line[/\A\d{1,2}(?::\d{2})?\s*[AP]M:\s*(.+)\z/i, 1] }.compact
      return timed_artists.join(", ") if timed_artists.present?

      featuring = text[/Featuring:\s*(.*?)(?:\s+DJs?\s*(?:&|,)\s*Hosts:|\s+Plus\s+dozens|\z)/i, 1]
      if featuring.present?
        return split_billing(featuring.sub(/\.\z/, ""))
      end
    end

    def body_billing(event)
      body = normalize_text(event.at_css(".mab-event-body-text")&.text)
      return "" if body.blank?

      billing =
        body[/\bfeaturing\s+(.+?)(?:\.|\s+\$|\s+21\+|\z)/i, 1] ||
        body[/\bwith special guests?\s+(.+?)(?:\.|\s+\$|\s+21\+|\z)/i, 1] ||
        body[/\bwith\s+(.+?)(?:\.|\s+\$|\s+21\+|\z)/i, 1]

      split_billing(billing)
    end

    def split_billing(value)
      normalize_text(value).
        gsub(/\s+with\s+/i, ", ").
        gsub(/,\s+and\s+/i, ", ").
        gsub(/\s*\+\s*/, ", ").
        split(/\s*,\s*/).
        map(&:strip).
        reject(&:blank?).
        join(", ")
    end

    def parse_date(event)
      date = Date.iso8601(event["data-date"])
      time = parse_time(event)
      Time.find_zone!(TIME_ZONE).local(date.year, date.month, date.day, time[:hour], time[:minute]).to_datetime
    end

    def parse_time(event)
      text = [
        normalize_text(event.at_css("details div")&.text),
        normalize_text(event.at_css(".mab-event-body-text")&.text),
        normalize_text(event.at_css(".mab-event-subtitle")&.text)
      ].join(" ")

      time_text =
        text[/\b(?:show|music begins|music at|doors\/show)(?:\s+at|:)?\s*(\d{1,2}(?::\d{2})?\s*[AP]M)/i, 1] ||
        text[/\b(\d{1,2}(?::\d{2})?\s*[AP]M)\s*:\s*[A-Z0-9]/i, 1] ||
        text[/\b(?:doors?)\s*(\d{1,2}(?::\d{2})?\s*[AP]M)/i, 1] ||
        text[/\b(\d{1,2}(?::\d{2})?\s*[AP]M)\b/i, 1]

      return { hour: 12, minute: 0 } if time_text.blank?

      time = Time.find_zone!(TIME_ZONE).parse(time_text)
      { hour: time.hour, minute: time.min }
    end

    def normalize_url(url)
      return nil if url.blank? || url.start_with?("#")
      return "https:#{url}" if url.start_with?("//")
      return URI.join(MAIN_URL, url).to_s if url.start_with?("/")

      url
    end

    def normalize_text(value)
      CGI.unescapeHTML(Nokogiri::HTML.fragment(value.to_s).text).
        gsub(/[\u2013\u2014]/, "-").
        gsub(/\u2022/, ",").
        gsub(/[[:space:]]+/, " ").
        strip
    end
  end
end
