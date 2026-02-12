require "uri"

class SfJazz
  MAIN_URL = "https://www.sfjazz.org/calendar/"

  cattr_accessor :months_limit, :events_limit
  self.events_limit = 200

  def self.run(events_limit: self.events_limit, &foreach_event_blk)
    events = []
    $driver.get(MAIN_URL)
    get_events.each do |event|
      break if events.count >= events_limit
      parsed = parse_event_data(event, &foreach_event_blk)
      events.push(parsed) if parsed
    end
    events
  end

  class << self
    private

    def get_events
      # scroll down so all the data is loaded
      3.times do
        $driver.execute_script("window.scrollBy(0,document.body.scrollHeight)")
      end
      sleep 2

      events = $driver.css(".ace-cal-list-event")
      return events if events.present?
      $driver.css(".calendar-list-view-event-container")
    end

    def parse_event_data(event, &foreach_event_blk)
      date = parse_date(event) rescue return
      url = event.css(".ace-cal-list-event-details a")[0]&.attribute("href") ||
            event.css("a.event-image")[0]&.attribute("href") ||
            MAIN_URL
      img = event.css(".ace-cal-list-event-image img")[0]&.attribute("src") ||
            event.css(".event-image img")[0]&.attribute("src") ||
            "https://ybgfestival.org/wp-content/uploads/2014/03/sfjazz-logo-21-300x300-300x300.jpg"
      title = event.css(".ace-cal-list-event-details h4")[0]&.text(strip: true) ||
              event.css(".event-info-title")[0]&.text(strip: true)
      return if title.blank?

      {
        url: absolutize_url(url),
        img: absolutize_url(img),
        date: date,
        title: title.gsub(/\s{2,}/, " "),
        details: ""
      }.
      tap { |data| Utils.print_event_preview(self, data) }.
      tap { |data| foreach_event_blk&.call(data) }
    rescue => e
      ENV["DEBUGGER"] == "true" ? binding.pry : raise
    end

    def parse_date(event)
      date_text = event.css(".ace-cal-list-day-of-month")[0]&.text(strip: true)
      if date_text.present?
        parsed = Date.parse("#{date_text} #{Date.today.year}")
        return DateTime.parse(parsed.to_s)
      end

      month = event.css(".event-date-month")[0]&.text
      day = event.css(".event-date-date")[0]&.text
      DateTime.parse("#{month}/#{day}")
    end

    def absolutize_url(url)
      return url if url.blank?
      URI.join(MAIN_URL, url).to_s
    rescue
      url
    end
  end
end
