class Knockout
	# "Load more" type site
  MAIN_URL = "https://theknockoutsf.com/calendar2"
  NEXT_MONTH_SELECTOR = "a[aria-label='Go to next month'], button[aria-label='Go to next month']"
  DAY_CELL_SELECTOR = "td[role='gridcell'], [role='gridcell']"
  MONTH_HEADING_SELECTOR = "h1, .yui3-calendar-header-label, div[aria-role='heading'], div[role='heading'], [aria-live='polite']"

  cattr_accessor :pages_limit, :events_limit
  self.pages_limit = 5
  self.events_limit = 200

	def self.run(events_limit: self.events_limit, &foreach_event_blk)
		index = 0
		events = []
		loop do
			added = []
			days = get_days(index)
			days.each do |day_container|
				new_events = day_container.css(".item-link")
				added.concat(new_events)
				new_events.each do |event|
	        		next if events.count >= events_limit
					events.push(parse_event_data(day_container, event, &foreach_event_blk))
				end
			end
			break if events.count >= events_limit
			break if added.empty? || index > pages_limit
			index += 1
		end
		events
	end

	class << self
		private
		def get_days(page_idx)
			$driver.navigate.to(MAIN_URL)
			page_idx.times do
				sleep 1
				$driver.css(NEXT_MONTH_SELECTOR)[0]&.click
				sleep 1
			end
			$driver.css(DAY_CELL_SELECTOR).select { |day| day.css("a").any? }
		end

		def parse_event_data(day_container, event, &foreach_event_blk)
			month, year = current_month_and_year
			day = parse_day(day_container)

			title = event.css(".item-title")[0]&.text
			url = event.attribute("href")
			img = parse_img(url)

			{
				date: DateTime.parse("#{month} #{day}, #{year}"),
				url: url,
				title: title,
				img: img,
				details: "",
			}.
				tap { |data| Utils.print_event_preview(self, data) }.
				tap { |data| foreach_event_blk&.call(data) }
		rescue => e
			ENV["DEBUGGER"] == "true" ? binding.pry : raise
		end

		def current_month_and_year
			heading = $driver.css(MONTH_HEADING_SELECTOR).map { |el| el.text.to_s.strip }.find do |text|
				text.match?(/\A[A-Z][a-z]+ \d{4}\z/)
			end
			raise "Knockout missing month heading" if heading.blank?
			heading.split(" ")
		end

		def parse_day(day_container)
			text = day_container.text.to_s
			day = day_container.css(".marker-daynum")[0]&.text.to_s[/\d+/]
			day ||= text[/\A\s*(\d{1,2})\b/, 1]
			raise "Knockout missing day number" if day.blank?
			day
		end

		def parse_img(url)
			$driver.new_tab(url) do
				$driver.css("meta[property='og:image']")[0]&.attribute("content")
			end
		rescue
			nil
		end
	end
end
