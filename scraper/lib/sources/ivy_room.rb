require "json"
require "faraday"

class IvyRoom
  MAIN_URL = "https://www.ivyroom.com/calendar?view=calendar"
  GRAPHQL_URL = "https://www.venuepilot.co/graphql"
  PROXY_URL = "https://cvgpjtvvxhdinrszyykk.supabase.co/functions/v1/fetch-proxy"
  ACCOUNT_ID = 992
  GRAPHQL_QUERY = <<~GRAPHQL.freeze
    query ($accountIds: [Int!]!, $startDate: String!, $endDate: String, $search: String, $searchScope: String, $limit: Int, $page: Int) {
      paginatedEvents(arguments: {accountIds: $accountIds, startDate: $startDate, endDate: $endDate, search: $search, searchScope: $searchScope, limit: $limit, page: $page}) {
        collection {
          name
          date
          doorTime
          startTime
          support
          description
          websiteUrl
          ticketsUrl
          announceImages {
            highlighted
            versions {
              thumb {
                src
              }
              cover {
                src
              }
            }
          }
        }
        metadata {
          totalPages
        }
      }
    }
  GRAPHQL

  cattr_accessor :events_limit
  self.events_limit = 200

  def self.run(events_limit: self.events_limit, &foreach_event_blk)
    events = []
    page = 1
    total_pages = nil

    while total_pages.nil? || page <= total_pages
      payload = fetch_events_page(page: page)
      data = payload.fetch("data", {})
      paginated = data.fetch("paginatedEvents", {})
      source_events = paginated.fetch("collection", [])
      total_pages = paginated.fetch("metadata", {}).fetch("totalPages", 1).to_i

      break if source_events.empty?

      source_events.each do |event|
        break if events.count >= events_limit
        result = parse_event_data(event, &foreach_event_blk)
        events << result if result
      end

      break if events.count >= events_limit
      page += 1
    end

    puts "Ivy room: #{events.count}"
    events
  end

  class << self
    private

    def fetch_events_page(page:)
      proxy_key = ENV["PROXY_SERVICE_KEY"].presence
      raise "IvyRoom missing PROXY_SERVICE_KEY env var" unless proxy_key

      graphql_body = {
        operationName: nil,
        variables: {
          accountIds: [ACCOUNT_ID],
          startDate: Date.today.strftime("%Y-%m-%d"),
          endDate: nil,
          search: "",
          searchScope: "",
          page: page
        },
        query: GRAPHQL_QUERY
      }.to_json

      request_body = {
        url: GRAPHQL_URL,
        options: {
          method: "POST",
          headers: {
            "accept" => "*/*",
            "accept-language" => "en-US,en;q=0.9",
            "content-type" => "application/json",
            "priority" => "u=1, i",
            "sec-ch-ua" => "\"Not(A:Brand\";v=\"8\", \"Chromium\";v=\"144\", \"Brave\";v=\"144\"",
            "sec-ch-ua-mobile" => "?0",
            "sec-ch-ua-platform" => "\"macOS\"",
            "sec-fetch-dest" => "empty",
            "sec-fetch-mode" => "cors",
            "sec-fetch-site" => "cross-site",
            "sec-gpc" => "1",
            "referer" => "https://www.ivyroom.com/"
          },
          body: graphql_body
        }
      }.to_json

      response = Faraday.post(PROXY_URL) do |req|
        req.headers["content-type"] = "application/json"
        req.headers["authorization"] = "Bearer #{proxy_key}"
        req.body = request_body
      end

      unless response.success?
        raise "IvyRoom proxy request failed (#{response.status}): #{response.body}"
      end

      parsed = JSON.parse(response.body)
      if parsed["errors"].present?
        raise "IvyRoom GraphQL errors: #{parsed['errors'].to_json}"
      end

      parsed
    rescue JSON::ParserError => e
      raise "IvyRoom invalid JSON response: #{e.message}"
    end

    def parse_event_data(event, &foreach_event_blk)
      title = [event["name"], event["support"]].map(&:presence).compact.join(", ")
      return if title.blank?

      {
        date: parse_date(event["date"], event["startTime"].presence || event["doorTime"].presence),
        url: normalize_url(event["ticketsUrl"].presence || event["websiteUrl"].presence || MAIN_URL),
        title: title,
        details: event["description"].to_s.strip,
        img: parse_image(event)
      }.
        tap { |data| Utils.print_event_preview(self, data) }.
        tap { |data| foreach_event_blk&.call(data) }
    rescue => e
      ENV["DEBUGGER"] == "true" ? binding.pry : raise
    end

    def parse_image(event)
      images = Array(event["announceImages"])
      preferred = images.find { |img| img["highlighted"] } || images.first || {}
      preferred.dig("versions", "cover", "src").presence ||
        preferred.dig("versions", "thumb", "src").to_s
    end

    def normalize_url(url)
      return MAIN_URL if url.blank?
      return "https://www.ivyroom.com#{url}" if url.start_with?("/")
      url
    end

    def parse_date(date_string, start_time)
      raise "IvyRoom missing event date" if date_string.blank?
      return DateTime.parse(date_string) if start_time.blank?
      DateTime.parse("#{date_string} #{start_time}")
    rescue ArgumentError
      DateTime.parse(date_string)
    end
  end
end
