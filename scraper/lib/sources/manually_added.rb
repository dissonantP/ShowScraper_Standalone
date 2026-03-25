class ManuallyAdded

  def self.run(events_limit: 0, &foreach_event_blk)
    load_existing_events.map do |event|
      event.
        tap { |data| Utils.print_event_preview(self, data) }.
        tap { |data| foreach_event_blk&.call(data) }
    end
  end

  def self.load_existing_events
    return [] if GCS.nil?

    raw = GCS.download_file_as_text(source: "ManuallyAdded.json").to_s
    return [] if raw.blank?

    parsed = JSON.parse(raw)
    unless parsed.is_a?(Array)
      puts "WARNING: ManuallyAdded.json did not contain a JSON array; preserving nothing"
      return []
    end

    parsed.filter_map do |event|
      next unless event.is_a?(Hash)

      event.deep_symbolize_keys
    end
  rescue JSON::ParserError => e
    puts "WARNING: failed to parse ManuallyAdded.json: #{e.message}"
    []
  rescue => e
    puts "WARNING: failed to load ManuallyAdded.json from GCS: #{e.class} #{e.message}"
    []
  end
end
