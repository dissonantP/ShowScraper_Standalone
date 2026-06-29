require "date"
require "nokogiri"
require "open-uri"

class SiestaValleyBowl
  MAIN_URL = "https://www.siestavalleybowl.com/"
  CALENDAR_URL = "#{MAIN_URL}shows-calendar"

  cattr_accessor :events_limit
  self.events_limit = 200

  def self.run(events_limit: self.events_limit, &foreach_event_blk)
    doc = Nokogiri::HTML(URI.open(CALENDAR_URL, "User-Agent" => "Mozilla/5.0").read)

    doc.css(".w-dyn-item")
      .select { |item| item.at_css(".svb-show-card") }
      .first(events_limit)
      .filter_map { |item| parse_event_data(item, &foreach_event_blk) }
  end

  class << self
    private

    def parse_event_data(item, &foreach_event_blk)
      card = item.at_css(".svb-show-card")
      title = card["data-artist"].to_s.strip
      return if title.empty?

      support = card["data-support"].to_s.strip
      details = [support.presence && "Support: #{support}", extract_bio(item)].compact.join("\n\n")

      {
        url: normalize_url(card["data-ticket"].presence || card["href"]),
        img: card.at_css(".svb-show-img")&.[]("src").to_s,
        date: parse_date(item.at_css("[data-event-date='true']")&.text, card["data-time"]),
        title: title,
        details: details
      }.
        tap { |data| Utils.print_event_preview(self, data) }.
        tap { |data| foreach_event_blk&.call(data) }
    rescue => e
      ENV["DEBUGGER"] == "true" ? binding.pry : raise
    end

    def extract_bio(item)
      item.at_css(".svb-hidden-bio")&.xpath(".//text()")&.map(&:text)&.join(" ")&.gsub(/\s+/, " ")&.strip.to_s
    end

    def normalize_url(url)
      return CALENDAR_URL if url.blank?
      return "#{MAIN_URL.delete_suffix('/')}#{url}" if url.start_with?("/")
      url
    end

    def parse_date(date_text, time_text)
      raise "SiestaValleyBowl missing event date" if date_text.blank?

      DateTime.parse([date_text.to_s.strip, time_text.to_s.strip].reject(&:empty?).join(" "))
    end
  end
end
