class OReilleysPub
  # Eventbrite, "load more" site
  MAIN_URL = "https://www.eventbrite.com/o/oreillys-pub-sf-presents-6806338175"

  cattr_accessor :months_limit, :events_limit
  self.months_limit = 3
  self.events_limit = 200

  def self.run(events_limit: self.events_limit, &foreach_event_blk)
    events = []
    $driver.get(MAIN_URL)
    # 5.times { get_next_page }
    sleep 5
    listings = get_events.select(&:displayed?)
    listings.each do |event|
      next if events.count >= events_limit
      result = parse_event_data(event, &foreach_event_blk)
      events.push(result) if result.present?
    end
    results = events.uniq { |e| [e[:date].strftime("%m/%d/%Y"), e[:title]] }.sort_by { |e| e[:date] }
    # binding.pry
    results
  end

  class << self
    private

    def get_events
      $driver.css(".event-card")
    end

    def get_next_page
      btns = $driver.css(".organizer-profile__show-more button")
      return false unless btns.length > 1
      btns[0]&.click if btns[0].displayed?
      sleep 1
      true
    end

    def parse_event_data(event, &foreach_event_blk)
      # binding.pry
      title = event.css(".event-card__clamp-line--two")[0].text
      date = parse_date(event) rescue nil
      return if title.blank?
      return if date.blank?
      {
        url: event.css(".event-card-link")[0].attribute("href"),
        img: event.css(".event-card-image")[0]&.attribute("src") || "https://img.evbuc.com/https%3A%2F%2Fcdn.evbuc.com%2Fimages%2F508879929%2F78654724783%2F1%2Foriginal.20230505-225547?h=230&w=460&auto=format%2Ccompress&q=75&sharp=10&rect=0%2C152%2C1242%2C621&s=39c1c2c43fbea1958ab34d2b46660fcc",
        date: date,
        title: title,
        details: ""
      }.
        tap { |data| Utils.print_event_preview(self, data) }.
        tap { |data| foreach_event_blk&.call(data) }
    rescue => e
      ENV["DEBUGGER"] == "true" ? binding.pry : raise
    end

    # The dates here are super annoying. Sometimes it's Monday, March 8 which can be easily parsed
    # Sometimes it's stuff like "Tuesday 8PM" which refers to the next occurring Tuesday.
    def parse_date(event)
      date_str = event.css(".event-card__clamp-line--one")[0].text.to_s.gsub(/\s+/, " ").strip
      normalized = date_str.sub(/\s*\+\s*\d+\s+more\z/i, "").gsub("•", ", ").gsub(/\s+,/, ",").squeeze(" ").strip
      downcased = normalized.downcase

      if downcased.include?("today")
        parse_relative_day(normalized, 0)
      elsif downcased.include?("tomorrow")
        parse_relative_day(normalized, 1)
      elsif downcased.include?("yesterday")
        parse_relative_day(normalized, -1)
      elsif normalized.match?(/\A[a-z]+,\s*\d{1,2}(:\d{2})?\s*[ap]m\z/i)
        parse_next_weekday(normalized)
      elsif normalized.match?(/\A[a-z]+,\s*[a-z]{3,9}\s+\d{1,2}(,?\s+\d{1,2}(:\d{2})?\s*[ap]m)?\z/i)
        DateTime.parse("#{normalized} #{Date.today.year}")
      elsif normalized.match?(/\A[a-z]{3},\s*[a-z]{3}\s+\d{1,2}/i) # e.g. Fri, Feb 20
        DateTime.parse("#{normalized} #{Date.today.year}")
      elsif normalized.include?(",")
        DateTime.parse(normalized)
      else # e.g. "Tuesday 8PM"
        parse_next_weekday(normalized)
      end
    end

    def parse_relative_day(str, day_offset)
      target_date = Date.today + day_offset
      time = str[/(\d{1,2}(?::\d{2})?\s*[AP]M)/i, 1]
      return DateTime.parse(target_date.to_s) if time.blank?
      DateTime.parse("#{target_date} #{time}")
    end

    def parse_next_weekday(str)
      # Map weekday names to their corresponding wday numbers (0-6, Sunday is 0)
      weekday_map = {
        "Sunday" => 0, "Monday" => 1, "Tuesday" => 2, "Wednesday" => 3,
        "Thursday" => 4, "Friday" => 5, "Saturday" => 6
      }

      # Get the current DateTime
      now = DateTime.now

      # Extract the target weekday's number
      weekday_name = weekday_map.keys.find { |k| str.downcase.include?(k.downcase) }
      return nil if weekday_name.blank?
      target_weekday = weekday_map[weekday_name]

      # Calculate the difference in days to the next occurrence of the target weekday
      days_difference = (target_weekday - now.wday) % 7
      days_difference = 7 if days_difference == 0 # If today is the target day, set to next week

      # Calculate the next occurrence of the target weekday and time
      next_occurrence = now + days_difference
      time = str[/(\d{1,2})(?::(\d{2}))?\s*([AP]M)/i, 0]
      if time.present?
        parsed_time = DateTime.parse(time)
        next_occurrence = DateTime.new(next_occurrence.year, next_occurrence.month, next_occurrence.day, parsed_time.hour, parsed_time.min)
      else
        next_occurrence = DateTime.new(next_occurrence.year, next_occurrence.month, next_occurrence.day)
      end

      next_occurrence
    end

  end
end
