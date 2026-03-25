require "uri"

class SfJazz
  MAIN_URL = "https://www.sfjazz.org/calendar/"
  DEFAULT_IMG = "https://ybgfestival.org/wp-content/uploads/2014/03/sfjazz-logo-21-300x300-300x300.jpg"

  cattr_accessor :events_limit
  self.events_limit = 200

  def self.run(events_limit: self.events_limit, &foreach_event_blk)
    $driver.navigate.to(MAIN_URL)
    wait_for_events!

    get_events.first(events_limit).map do |event|
      parse_event_data(event, &foreach_event_blk)
    end.compact
  end

  class << self
    private

    def wait_for_events!
      20.times do
        events = get_events
        return if events.any?
        sleep 0.5
      end

      raise "SfJazz calendar events did not load"
    end

    def get_events
      $driver.css(".ace-cal-list-event")
    end

    def parse_event_data(event, &foreach_event_blk)
      title = event.css(".ace-cal-list-event-details h4").first&.text.to_s.strip
      return if title.blank?

      link =
        event.css(".ace-cal-list-event-details a").first ||
        event.css(".ace-cal-list-event-image a").first

      img = event.css(".ace-cal-list-event-image img").first&.attribute("src").presence || DEFAULT_IMG
      date = parse_date(event)
      details = event.css(".ace-cal-list-event-time").first&.text.to_s.squish

      {
        url: absolutize_url(link&.attribute("href").presence || MAIN_URL),
        img: absolutize_url(img),
        date: date,
        title: title,
        details: details
      }.
        tap { |data| Utils.print_event_preview(self, data) }.
        tap { |data| foreach_event_blk&.call(data) }
    rescue => e
      ENV["DEBUGGER"] == "true" ? binding.pry : raise
    end

    def parse_date(event)
      month_day = event.css(".ace-cal-list-day-of-month").first&.text.to_s.squish
      raise "SfJazz missing event date" if month_day.blank?

      candidate = DateTime.parse("#{month_day} #{Date.today.year}")
      candidate = candidate.next_year if candidate.to_date < Date.today - 31
      candidate
    end

    def absolutize_url(url)
      URI.join(MAIN_URL, url).to_s
    rescue
      url
    end
  end
end
