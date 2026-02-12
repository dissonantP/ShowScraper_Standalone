class Paramount
  MAIN_URL = "https://www.paramountoakland.org/events"
  LIST_VIEW_SELECTOR = "[aria-label='Toggle to List View']"
  LOAD_MORE_SELECTOR = "#loadMoreEvents"

  cattr_accessor :months_limit, :events_limit, :load_time
  self.events_limit = 200
  self.load_time = 2

  def self.run(events_limit: self.events_limit, &foreach_event_blk)
    events = []

    $driver.get(MAIN_URL)
    sleep self.load_time
    switch_to_list_view
    load_all_events

    get_events.each do |event|
      next if events.count >= events_limit
      result = parse_event_data(event, &foreach_event_blk)
      events.push(result) if result.present?
    end

    events
  end

  class << self
    private

    def get_events
      $driver.css(".eventItem")
    end

    def switch_to_list_view
      btn = $driver.css(LIST_VIEW_SELECTOR)[0]
      return if btn.nil?
      btn.click
      sleep 1
    rescue
      nil
    end

    def load_all_events
      loop do
        got_next_page = get_next_page
        break unless got_next_page
      end
    end

    def get_next_page
      btn = $driver.css(LOAD_MORE_SELECTOR)[0]
      return false if btn.nil?
      if btn.attribute("disabled")
        return false
      end
      current_count = get_events.count
      $driver.execute_script("arguments[0].scrollIntoView({block:'center'});", btn)
      btn.click
      sleep 1
      next_count = get_events.count
      return false if next_count <= current_count && btn.attribute("disabled")
      true
    rescue
      false
    end

    def parse_event_data(event, &foreach_event_blk)
      url = event.css(".title a")[0]&.attribute("href")
      img = event.css(".thumb img")[0]&.attribute("src")
      title = event.css(".title")[0]&.text(strip: true)
      date = parse_date(event) rescue nil
      return if url.blank? || title.blank? || date.blank?

      {
        url: url,
        img: img,
        date: date,
        title: title,
        details: ""
      }.
        tap { |data| Utils.print_event_preview(self, data) }.
        tap { |data| foreach_event_blk&.call(data) }
    rescue => e
      ENV["DEBUGGER"] == "true" ? binding.pry : nil
    end

    def parse_date(event)
      date_text = event.css(".m-date")[0]&.text(strip: true).to_s
      date_text = date_text.gsub("|", " ")
      return DateTime.parse(date_text) if date_text.present?

      month = event.css(".m-date__month")[0]&.text.to_s
      day = event.css(".m-date__day")[0]&.text.to_s
      year = event.css(".m-date__year")[0]&.text.to_s.gsub(/[^\d]/, "")
      DateTime.parse("#{month} #{day}, #{year}")
    end
  end
end
