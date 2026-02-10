require "google/cloud/storage"
require "tempfile"
require "stringio"

class GCS
  # CACHE_CONTROL = "Cache-Control:max-age=300" # 5 minutes cache
  CACHE_CONTROL = "Cache-Control:no-cache"

  cattr_accessor :storage, :bucket_name, :bucket

  self.storage = Google::Cloud::Storage.new(
    project_id: ENV.fetch("STORAGE_PROJECT"),
    credentials: "credentials/credentials.json"
  )
  self.bucket_name = ENV.fetch(ENV["TEST"] == "true" ? "GCS_TEST_BUCKET" : "GCS_BUCKET")
  self.bucket = storage.bucket(bucket_name)

  def self.upload_file(source:, dest:)
    bucket.create_file(source, dest, cache_control: CACHE_CONTROL)
  end

  def self.upload_text_as_file(text:, dest:)
    upload_file(source: StringIO.new(text), dest: dest)
  end

  def self.download_file(source:, dest:)
    file = bucket.file(source)
    return false unless file
    file.download(dest)
    true
  end

  def self.download_file_as_text(source:)
    temp = Tempfile.new
    return nil unless download_file(source: source, dest: temp.path)
    temp.rewind
    temp.read
  ensure
    temp&.close!
  end
end
