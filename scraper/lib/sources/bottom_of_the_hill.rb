class BottomOfTheHill
  # No pagination needed here, all events shown at once.
  MAIN_URL = "http://www.bottomofthehill.com/calendar.html"

  cattr_accessor :events_limit
  self.events_limit = 200

  def self.run(events_limit: self.events_limit, &foreach_event_blk)
    index = 0
    get_events.each.map do |event|
      next if index >= events_limit
      next if event.css(".date").empty? # they have non-events in the same table
      result = parse_event_data(event, &foreach_event_blk)
      index += 1 if result
      result
    end.compact
  end

  class << self
    private

    def get_events
      $driver.navigate.to(MAIN_URL)
      $driver.css("#listings tr")
    end

    def parse_event_data(event, &foreach_event_blk)
      img = parse_img(event)
      link = parse_details_link(event) || infer_details_link_from_img(img) || MAIN_URL
      title = parse_title(event)
      date = parse_date(event.css(".date").map(&:text).reject(&:blank?).join("")) rescue return
      return if title.blank?
      {
        date: date,
        img: img || "https://upload.wikimedia.org/wikipedia/commons/2/2a/Bottom_of_the_hill.jpg",
        title: title,
        url: link,
        details: "",
      }.
        tap { |data| Utils.print_event_preview(self, data) }.
        tap { |data| foreach_event_blk&.call(data) }
    rescue => e
      ENV["DEBUGGER"] == "true" ? binding.pry : raise
    end

    def parse_title(event)
      event.css(".band").map(&:text).map do |title|
        title.to_s.gsub(/\u00A0/, " ").gsub(/\s+/, " ").strip
      end.reject(&:blank?).join(", ")
    end

    def parse_img(event)
      event.css("img").map do |event|
        event.attribute("src")
      end.find do |img|
        img =~ /http:\/\/www.bottomofthehill.com\/f/
      end
    end

    def parse_details_link(event)
      hrefs = event.css("a").map { |node| node.attribute("href").to_s.strip }.reject(&:blank?)

      # Some events use letter-suffixed pages like 20260228A.html.
      candidate = hrefs.find { |url| url.match?(%r{/(?:\d{8}[A-Za-z]?)\.html\z}i) } || hrefs.first
      normalize_url(candidate)
    end

    def infer_details_link_from_img(img_url)
      return if img_url.blank?
      match = img_url.match(%r{/f/(\d{8}[A-Za-z]?)[[:alnum:]-]*\.(?:jpg|jpeg|png)\z}i)
      return if match.blank?
      "http://www.bottomofthehill.com/#{match[1]}.html"
    end

    def normalize_url(url)
      return if url.blank?
      return "http://www.bottomofthehill.com#{url}" if url.start_with?("/")
      url
    end

    def parse_details
      time = $driver.css(".time").map(&:text).join(" ")
      websites = $driver.css(".website").map(&:text).join("\n")
      genres = $driver.css(".genre").map(&:text).join("\n")
      [time, websites, genres].join("\n")
    end

    def parse_date(date_string)
      DateTime.parse(date_string)
    end
  end
end
