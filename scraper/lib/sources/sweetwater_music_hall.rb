require "nokogiri"
require "open-uri"
require "set"
require "time"

class SweetwaterMusicHall
  MAIN_URL = "https://sweetwatermusichall.org/events/"
  TIME_ZONE = "America/Los_Angeles"

  cattr_accessor :events_limit
  self.events_limit = 200

  def self.run(events_limit: self.events_limit, &foreach_event_blk)
    events = []
    page_url = MAIN_URL
    seen_page_signatures = Set.new

    while page_url.present? && events.count < events_limit
      doc = fetch_page(page_url)
      source_events = get_events(doc)
      break if source_events.empty?

      signature = page_signature(source_events)
      break unless seen_page_signatures.add?(signature)

      source_events.each do |event|
        break if events.count >= events_limit

        result = parse_event_data(event, &foreach_event_blk)
        events << result if result.present?
      end

      page_url = next_page_url(doc)
    end

    events
  end

  class << self
    private

    def fetch_page(url)
      Nokogiri::HTML(URI.open(url).read)
    end

    def get_events(doc)
      doc.css(".rhpSingleEvent")
    end

    def next_page_url(doc)
      doc.at_css("link[rel='next']")&.attribute("href")&.value
    end

    def page_signature(events)
      events.map { |event| parse_url(event) }.join("|")
    end

    def parse_event_data(event, &foreach_event_blk)
      title = clean_text(event.at_css("a#eventTitle")&.text)
      date_text = clean_text(event.at_css(".eventDateList")&.text)
      time_text = clean_text(event.at_css(".eventDoorStartDate")&.text)
      date = parse_date(date_text, parse_show_time(time_text))
      return if title.blank? || date.to_date < Date.today

      {
        url: parse_url(event),
        img: event.at_css("img.eventListImage")&.attribute("src")&.value.to_s,
        date: date,
        title: title,
        details: ""
      }.
        tap { |data| Utils.print_event_preview(self, data) }.
        tap { |data| foreach_event_blk&.call(data) }
    rescue => e
      ENV["DEBUGGER"] == "true" ? binding.pry : raise
    end

    def parse_url(event)
      event.at_css("a#eventTitle")&.attribute("href")&.value ||
        event.at_css(".eventMoreInfo a")&.attribute("href")&.value
    end

    def parse_date(date_text, show_time)
      parse_pacific_time([date_text, show_time].reject(&:blank?).join(" "))
    end

    def parse_show_time(time_text)
      time_text[/Show:\s*(.*?)\z/i, 1].to_s.strip
    end

    def parse_pacific_time(value)
      Time.find_zone!(TIME_ZONE).parse(value).to_datetime
    end

    def clean_text(value)
      value.to_s.gsub(/\u00a0/, " ").squish
    end
  end
end
