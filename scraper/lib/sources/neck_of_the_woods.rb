require "nokogiri"
require "open-uri"

class NeckOfTheWoods
  MAIN_URL = "https://www.neckofthewoodssf.com/"

  cattr_accessor :events_limit
  self.events_limit = 200

  def self.run(events_limit: self.events_limit, &foreach_event_blk)
    events = []
    page = 1

    loop do
      doc = fetch_page(page)
      source_events = get_events(doc)
      break if source_events.empty?

      source_events.each do |event|
        break if events.count >= events_limit
        result = parse_event_data(event, &foreach_event_blk)
        events << result if result.present?
      end

      break if events.count >= events_limit
      break unless next_page?(doc)

      page += 1
    end

    events
  end

  class << self
    private

    def fetch_page(page)
      Nokogiri.parse(
        URI.open(page_url(page), "User-Agent" => "Mozilla/5.0").read
      )
    end

    def page_url(page)
      page == 1 ? MAIN_URL : "#{MAIN_URL}page/#{page}/"
    end

    def get_events(doc)
      doc.css(".tw-section")
    end

    def next_page?(doc)
      doc.at_css(".tm-paginate a.next").present?
    end

    def parse_event_data(event, &foreach_event_blk)
      name = event.at_css(".tw-name")&.text.to_s.squish
      return if name.blank?

      show_time = parse_show_time(event)

      {
        url: event.at_css(".tw-name a")&.attribute("href")&.value,
        img: event.at_css(".tw-image img")&.attribute("src")&.value.to_s,
        date: parse_date(event, show_time),
        title: [name, show_time].reject(&:blank?).join(" - "),
        details: ""
      }.
        tap { |data| Utils.print_event_preview(self, data) }.
        tap { |data| foreach_event_blk&.call(data) }
    rescue => e
      ENV["DEBUGGER"] == "true" ? binding.pry : raise
    end

    def parse_show_time(event)
      event.at_css(".tw-event-time")&.text.to_s.sub(/\AShow:\s*/i, "").strip
    end

    def parse_date(event, show_time)
      date_text = event.at_css(".tw-event-date")&.text.to_s.strip
      DateTime.parse([date_text, show_time].reject(&:blank?).join(" "))
    end
  end
end
