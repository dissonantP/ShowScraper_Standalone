require "open-uri"

class Indybay
  MAIN_URL = "https://www.indybay.org/calendar/ical_feed.php?topic_id=0&region_id=0"

  cattr_accessor :events_limit
  self.events_limit = 200

  def self.run(events_limit: self.events_limit, &foreach_event_blk)
    fetch_events.first(events_limit).map do |event|
      parse_event_data(event, &foreach_event_blk)
    end.compact
  end

  class << self
    private

    def fetch_events
      parse_ical_events(URI.open(MAIN_URL).read)
    end

    def parse_ical_events(raw_ical)
      current_event = nil

      unfolded_lines(raw_ical).each_with_object([]) do |line, events|
        case line
        when "BEGIN:VEVENT"
          current_event = {}
        when "END:VEVENT"
          events << current_event if current_event.present?
          current_event = nil
        else
          next unless current_event && line.include?(":")

          key, value = line.split(":", 2)
          current_event[key.split(";", 2).first] = value.to_s
        end
      end
    end

    def unfolded_lines(raw_ical)
      raw_ical.gsub("\r\n", "\n").split("\n").each_with_object([]) do |line, lines|
        if line.start_with?(" ", "\t") && lines.any?
          lines[-1] << line[1..]
        else
          lines << line
        end
      end
    end

    def parse_event_data(event, &foreach_event_blk)
      title = decode_ical_text(event["SUMMARY"]).to_s.strip
      url = event["URL"].to_s.strip
      location = decode_ical_text(event["LOCATION"]).to_s.strip
      description = decode_ical_text(event["DESCRIPTION"]).to_s.strip
      return if title.blank? || url.blank?

      cleaned_location = clean_location(location)

      {
        url: url,
        img: "",
        date: parse_date(event["DTSTART"]),
        title: [title, location_suffix(cleaned_location)].compact.join(" "),
        details: [location.presence && "Location: #{location}", description.presence].compact.join("\n\n"),
        location: cleaned_location
      }.
        tap { |data| Utils.print_event_preview(self, data) }.
        tap { |data| foreach_event_blk&.call(data) }
    rescue => e
      ENV["DEBUGGER"] == "true" ? binding.pry : raise
    end

    def decode_ical_text(value)
      value.to_s.
        gsub(/\\[nN]/, "\n").
        gsub("\\,", ",").
        gsub("\\;", ";").
        gsub("\\\\", "\\")
    end

    def parse_date(value)
      DateTime.parse(value.to_s)
    rescue ArgumentError
      Date.parse(value.to_s).to_datetime
    end

    def clean_location(value)
      value.to_s.
        gsub(%r{https?://\S+}, "").
        lines.map(&:strip).
        reject(&:blank?).
        join(" ")
    end

    def location_suffix(location)
      return nil if location.blank?

      "(Location: #{location})"
    end
  end
end
