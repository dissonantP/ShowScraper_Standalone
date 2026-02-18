require "json"
require "faraday"
require "uri"

class SfJazz
  MAIN_URL = "https://www.sfjazz.org/calendar/"
  EVENTS_API_URL = "https://www.sfjazz.org/ace-api/events/"
  PROXY_URL = "https://cvgpjtvvxhdinrszyykk.supabase.co/functions/v1/fetch-proxy"
  DEFAULT_IMG = "https://ybgfestival.org/wp-content/uploads/2014/03/sfjazz-logo-21-300x300-300x300.jpg"

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
      proxy_key = ENV["PROXY_SERVICE_KEY"].presence
      raise "SfJazz missing PROXY_SERVICE_KEY env var" unless proxy_key

      start_date = Date.today.strftime("%Y-%m-%d")
      end_date = (Date.today >> 4).strftime("%Y-%m-%d")

      request_body = {
        url: "#{EVENTS_API_URL}?startDate=#{start_date}&endDate=#{end_date}",
        options: {
          method: "GET",
          headers: {
            "user-agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "accept" => "application/json, text/plain, */*",
            "accept-language" => "en-US,en;q=0.9",
            "referer" => MAIN_URL,
            "origin" => "https://www.sfjazz.org",
            "sec-fetch-dest" => "empty",
            "sec-fetch-mode" => "cors",
            "sec-fetch-site" => "same-origin",
            "sec-ch-ua" => "\"Chromium\";v=\"122\", \"Not(A:Brand\";v=\"24\"",
            "sec-ch-ua-mobile" => "?0",
            "sec-ch-ua-platform" => "\"macOS\""
          }
        }
      }.to_json

      response = Faraday.post(PROXY_URL) do |req|
        req.headers["content-type"] = "application/json"
        req.headers["authorization"] = "Bearer #{proxy_key}"
        req.body = request_body
      end

      unless response.success?
        raise "SfJazz proxy request failed (#{response.status}): #{response.body}"
      end

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise "SfJazz invalid JSON response: #{e.message}"
    end

    def parse_event_data(event, &foreach_event_blk)
      title = event["name"].to_s.strip
      return if title.blank?

      date = DateTime.parse(event["eventDate"]) rescue nil
      return if date.blank?

      link = event["viewDetailCtaUrl"].presence || event["buyTicketCtaUrl"].presence || MAIN_URL
      img = event["thumbnail"].presence || DEFAULT_IMG
      details = event["location"].to_s.strip

      {
        url: absolutize_url(link.presence || MAIN_URL),
        img: absolutize_url(img.presence || DEFAULT_IMG),
        date: date,
        title: title.gsub(/\s{2,}/, " "),
        details: details
      }.
        tap { |data| Utils.print_event_preview(self, data) }.
        tap { |data| foreach_event_blk&.call(data) }
    rescue => e
      ENV["DEBUGGER"] == "true" ? binding.pry : raise
    end

    def absolutize_url(url)
      URI.join(MAIN_URL, url).to_s
    rescue
      url
    end
  end
end
