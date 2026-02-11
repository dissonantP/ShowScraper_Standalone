#!/usr/bin/env ruby
require 'fileutils'
require 'open3'

class SetupScript
  GECKODRIVER_VERSION = 'v0.35.0'
  GECKODRIVER_URL = 'https://github.com/mozilla/geckodriver/releases/download'

  def initialize
    @failed = false
  end

  def run
    puts "🚀 Setting up ShowScraper environment...\n\n"

    check_ruby
    check_firefox
    install_geckodriver
    install_gems
    create_directories

    if @failed
      puts "\n❌ Setup completed with errors. Please fix the issues above."
      exit 1
    else
      puts "\n✅ Setup complete! You can now run: bin/run_scraper"
      exit 0
    end
  end

  private

  def check_ruby
    print "Checking Ruby... "
    version = `ruby -v`.strip
    puts "✓ #{version}"
  end

  def check_firefox
    print "Checking Firefox... "
    begin
      output, status = Open3.capture2('firefox --version')
      if status.success?
        puts "✓ #{output.strip}"
        return
      end
    rescue Errno::ENOENT
    end

    puts "✗ Firefox not found"

    if system('which apt-get > /dev/null 2>&1')
      puts "  Install with: sudo apt-get install firefox-esr"
    elsif system('which brew > /dev/null 2>&1')
      puts "  Install with: brew install firefox"
    else
      puts "  Install Firefox for your system and add it to PATH"
    end

    @failed = true
  end

  def install_geckodriver
    print "Checking Geckodriver... "

    if system('which geckodriver > /dev/null 2>&1')
      output, = Open3.capture2('geckodriver --version')
      puts "✓ #{output.lines.first.strip}"
      return
    end

    puts "not found, installing..."

    arch = `uname -m`.strip
    gecko_arch = case arch
                 when 'x86_64'
                  'linux64'
                 when 'arm64'
                  'macos-aarch64'
                 when 'aarch64'
                  'linux-aarch64'
                 else
                  puts "  ✗ Unsupported architecture: #{arch}"
                  @failed = true
                  return
                 end

    url = "#{GECKODRIVER_URL}/#{GECKODRIVER_VERSION}/geckodriver-#{GECKODRIVER_VERSION}-#{gecko_arch}.tar.gz"

    begin
      require 'net/http'
      require 'tempfile'

      temp_dir = Dir.mktmpdir
      tar_path = File.join(temp_dir, 'geckodriver.tar.gz')

      # Download
      uri = URI(url)
      Net::HTTP.get_response(uri) do |response|
        File.open(tar_path, 'wb') do |file|
          response.read_body do |chunk|
            file.write(chunk)
          end
        end
      end

      # Extract to /usr/local/bin
      system("tar xzf #{tar_path} -C #{temp_dir}")
      geckodriver_path = File.join(temp_dir, 'geckodriver')

      if File.exist?(geckodriver_path)
        # Try sudo first, fall back to local installation
        if system("sudo mv #{geckodriver_path} /usr/local/bin/geckodriver 2>/dev/null")
          system('sudo chmod +x /usr/local/bin/geckodriver')
          puts "  ✓ Installed to /usr/local/bin/geckodriver"
          # Set env var in .env
          set_env_var('GECKODRIVER_PATH', '/usr/local/bin/geckodriver')
        else
          # Install locally to bin directory
          bin_dir = 'bin'
          FileUtils.mkdir_p(bin_dir)
          FileUtils.cp(geckodriver_path, File.join(bin_dir, 'geckodriver'))
          File.chmod(0755, File.join(bin_dir, 'geckodriver'))
          puts "  ✓ Installed to ./bin/geckodriver"
          set_env_var('GECKODRIVER_PATH', File.join(Dir.pwd, 'bin', 'geckodriver'))
        end
      else
        puts "  ✗ Failed to extract geckodriver"
        @failed = true
      end

      FileUtils.rm_rf(temp_dir)
    rescue => e
      puts "  ✗ Error installing geckodriver: #{e.message}"
      @failed = true
    end
  end

  def install_gems
    print "Installing Ruby gems... "
    if system('bundle install --quiet')
      puts "✓"
    else
      puts "✗"
      puts "  Run: bundle install"
      @failed = true
    end
  end

  def create_directories
    print "Creating required directories... "
    FileUtils.mkdir_p('credentials')
    FileUtils.mkdir_p('logs')
    puts "✓"
  end

  def set_env_var(key, value)
    env_file = '.env'

    if File.exist?(env_file)
      content = File.read(env_file)
      if content.include?("#{key}=")
        content.gsub!(/^#{key}=.*$/, "#{key}=#{value}")
      else
        content += "\n#{key}=#{value}"
      end
    else
      content = "#{key}=#{value}\n"
    end

    File.write(env_file, content)
  end
end

SetupScript.new.run
