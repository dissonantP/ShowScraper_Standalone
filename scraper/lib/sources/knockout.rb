class Knockout
	# "Load more" type site
  MAIN_URL = "https://theknockoutsf.com/calendar2"
  NEXT_MONTH_SELECTOR = "a[aria-label='Go to next month'], button[aria-label='Go to next month']"
  DAY_CELL_SELECTOR = "td[role='gridcell'], [role='gridcell']"
  MONTH_HEADING_SELECTOR = "div[aria-role='heading'], div[role='heading'], [aria-live='polite']"

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
			$driver.css(DAY_CELL_SELECTOR)
		end

		def parse_event_data(day_container, event, &foreach_event_blk)
			month, year = $driver.css(MONTH_HEADING_SELECTOR)[0]&.text.to_s.split(" ")
			day = day_container.css(".marker-daynum")[0].text

			title = event.css(".item-title")[0]&.text
			url = event.attribute("href")
			img = nil
			$driver.new_tab(url) do
				img = $driver.css("meta[property='og:image']")[0].attribute("content")
			end

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
	end
end
