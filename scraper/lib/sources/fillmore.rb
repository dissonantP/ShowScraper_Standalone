class Fillmore
  # "Load more" type site
  # However they have aggressive bot detection.
  # So we just parse super minimal info here.

  cattr_accessor :pages_limit, :events_limit
  self.pages_limit = 5
  self.events_limit = 200

  MAIN_URL = "https://www.livenation.com/venue/KovZpZAE6eeA/the-fillmore-events"
  EVENTS_WAIT_TIMEOUT = 15
  EVENT_SCHEMA_SELECTOR = 'script[type="application/ld+json"]'

  def self.run(events_limit: self.events_limit, &foreach_event_blk)
    $driver.navigate.to(MAIN_URL)
    @page_event_urls = nil
    get_all_pages
    wait_for_events
    get_events.map.with_index do |event, index|
      next if index >= events_limit
      parse_event_data(event, &foreach_event_blk)
    end.compact
  end

  class << self
    private

    def get_events
      events = $driver.css("[role='tabpanel'] div[role='group']")
      events = $driver.css("div[role='group']") if events.empty?

      events.select do |box|
        box.text.present? && (box.css("time").present? || box.css("h2").present?)
      end
    end

    def get_all_pages
      sleep 2
      # ewww gross iframe
      $driver.execute_script 'document.querySelectorAll("iframe").forEach((iframe) => iframe.remove())'

      # And google ads ... livenation, everyone
      $driver.execute_script 'document.querySelectorAll("#adhesion-ad").forEach((iframe) => iframe.remove())'

      # while load_more = $driver.css(".show-more")[0]
      #   load_more.click
      #   sleep 1
      # end
    end

    def wait_for_events
      wait = Selenium::WebDriver::Wait.new(timeout: EVENTS_WAIT_TIMEOUT)
      wait.until { get_events.any? }
    rescue Selenium::WebDriver::Error::TimeoutError
      nil
    end

    def parse_event_data(event, &foreach_event_blk)
      date_node = event.css("time")[0]
      date = DateTime.parse(date_node.attribute("datetime")) rescue nil
      return if date.blank?

      title = event.css("h2")[0]&.text&.strip
      title = event.css(".chakra-heading")[0]&.text&.strip if title.blank?
      return if title.blank?

      link = event.css("a")[0]&.attribute("href")
      link = lookup_event_url(date: date, title: title) if link.blank?
      link = MAIN_URL if link.blank?

      {
        date: date,
        url: link,
        img: parse_img(event),
        title: title,
        details: "",
      }.
        tap { |data| Utils.print_event_preview(self, data) }.
        tap { |data| foreach_event_blk&.call(data) }
    rescue => e
      ENV["DEBUGGER"] == "true" ? binding.pry : raise
    end

    def parse_img(event)
      # Some wierd shit. The images don't load until you scroll to them.
      # But there's a workaround.
      img = event.css("img")[0]&.attribute("src").to_s
      return "" if img.blank?

      if img.include?("data")
        src_set = event.attribute("outerHTML").scan(/srcSet="([^"]+)"/)[0]&.first
        img = src_set.to_s.split(",")[6].to_s.lstrip
      end
      img
    rescue
      ""
    end

    def lookup_event_url(date:, title:)
      page_event_urls[[normalize_title(title), date.strftime("%Y-%m-%d")]]
    end

    def page_event_urls
      @page_event_urls ||= $driver.css(EVENT_SCHEMA_SELECTOR).each_with_object({}) do |script, urls|
        payload = JSON.parse(script.attribute("innerHTML")) rescue nil
        next unless payload.is_a?(Hash)
        next unless payload["@type"] == "MusicEvent"

        start_date = payload["startDate"].to_s.slice(0, 10)
        event_title = normalize_title(payload["name"])
        event_url = payload["url"].presence
        next if start_date.blank? || event_title.blank? || event_url.blank?

        urls[[event_title, start_date]] = event_url
      end
    end

    def normalize_title(title)
      title.to_s.squish.downcase
    end
  end
end
