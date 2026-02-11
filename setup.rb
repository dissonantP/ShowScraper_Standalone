#!/usr/bin/env ruby
require 'fileutils'
require 'open3'
require 'tmpdir'
require 'net/http'
require 'uri'
require 'shellwords'

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

    puts "not found, downloading..."
    install_firefox_binary
  end

  def install_firefox_binary
    arch = `uname -m`.strip
    os = `uname -s`.strip.downcase

    # Use direct FTP links to get consistent tar formats
    url = case [os, arch]
          when ['linux', 'x86_64']
            'https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=en-US'
          when ['linux', 'aarch64']
            'https://download.mozilla.org/?product=firefox-latest-ssl&os=linux-aarch64&lang=en-US'
          when ['darwin', 'arm64'], ['darwin', 'x86_64']
            # For macOS, we'll use homebrew since DMG extraction is complex
            install_firefox_homebrew
            return
          else
            puts "  ✗ Unsupported platform: #{os} #{arch}"
            @failed = true
            return
          end

    begin
      temp_dir = Dir.mktmpdir
      tar_path = File.join(temp_dir, 'firefox.tar.bz2')

      puts "  Downloading Firefox..."
      download_file(url, tar_path)

      puts "  Extracting Firefox..."
      # Try xz first, then bzip2
      unless system("tar xJf #{tar_path} -C #{temp_dir}") ||
             system("tar xjf #{tar_path} -C #{temp_dir}")
        puts "  ✗ Failed to extract Firefox"
        @failed = true
        return
      end

      firefox_path = File.join(temp_dir, 'firefox', 'firefox')
      if File.exist?(firefox_path)
        bin_dir = 'bin'
        FileUtils.mkdir_p(bin_dir)
        FileUtils.cp_r(File.join(temp_dir, 'firefox'), bin_dir)
        local_firefox_path = File.join(Dir.pwd, bin_dir, 'firefox', 'firefox')
        puts "  ✓ Installed to ./bin/firefox/firefox"
        set_env_var('FIREFOX_PATH', local_firefox_path)
      else
        puts "  ✗ Failed to find Firefox executable after extraction"
        @failed = true
      end

      FileUtils.rm_rf(temp_dir)
    rescue => e
      puts "  ✗ Error installing Firefox: #{e.message}"
      @failed = true
    end
  end

  def install_firefox_homebrew
    if system("which brew > /dev/null 2>&1")
      puts "not found, installing via Homebrew..."
      system("brew install firefox")
      set_env_var('FIREFOX_PATH', '/Applications/Firefox.app/Contents/MacOS/firefox')
    else
      puts "✗ Firefox not found and Homebrew not available for macOS installation"
      @failed = true
    end
  end

  def download_file(url, dest_path)
    # Try curl first (usually more reliable)
    if system("which curl > /dev/null 2>&1")
      return if system("curl -fsSL -L #{url.shellescape} -o #{dest_path.shellescape}")
    end

    # Fall back to wget
    if system("which wget > /dev/null 2>&1")
      return if system("wget -q -O #{dest_path.shellescape} #{url.shellescape}")
    end

    # Fall back to Ruby HTTP (less reliable for redirects)
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', max_retries: 3) do |http|
      request = Net::HTTP::Get.new(uri.request_uri)
      request['User-Agent'] = 'Mozilla/5.0'
      response = http.request(request)

      if response.code == '302' || response.code == '301'
        download_file(response['location'], dest_path)
        return
      end

      if response.is_a?(Net::HTTPSuccess)
        File.open(dest_path, 'wb') do |file|
          file.write(response.body)
        end
      else
        raise "HTTP #{response.code}: #{response.message}"
      end
    end
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
      temp_dir = Dir.mktmpdir
      tar_path = File.join(temp_dir, 'geckodriver.tar.gz')

      # Download
      download_file(url, tar_path)

      # Extract
      unless system("tar xzf #{tar_path} -C #{temp_dir}")
        puts "  ✗ Failed to extract geckodriver"
        @failed = true
        return
      end

      geckodriver_path = File.join(temp_dir, 'geckodriver')

      if File.exist?(geckodriver_path)
        # Try sudo first, fall back to local installation
        if system("sudo mv #{geckodriver_path} /usr/local/bin/geckodriver 2>/dev/null")
          system('sudo chmod +x /usr/local/bin/geckodriver')
          puts "  ✓ Installed to /usr/local/bin/geckodriver"
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
