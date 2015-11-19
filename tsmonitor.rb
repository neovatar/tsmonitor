require 'teamspeak-ruby'
require 'pp'
require 'pp'
require 'optparse'
require 'ostruct'

class Optparser
  def self.parse(args)
    options = OpenStruct.new
    options.wait     = 10
    options.user     = nil
    options.password = ''
    options.host     = 'localhost'
    options.port     = 15011
    options.instance = nil

    opts = OptionParser.new do |o|
      o.banner = 'Usage: ts3-monitor.rb [options]'
      o.separator ''
      o.separator 'Specific options:'

      o.on('-d', '--delay DELAY', 'Delay before repeating checks') do |wait|
        options.wait = wait.to_i
      end

      o.on('-u', '--user USER', 'Login as this teamspeak user') do |user|
        options.user = user
      end

      o.on('-p', '--password USER', 'Login with this password') do |password|
        options.password = password
      end

      o.on('-P', '--port PORT', 'Connect to this port') do |port|
        options.port = port
      end

      o.on('-h', '--host HOST', 'Connect to this host') do |host|
        options.host = host
      end

      o.on('-i', '--instance INSTANCE', 'Use this instance name') do |instance|
        options.instance = instance
      end

      o.separator ''
      o.separator 'Common options:'

      o.on_tail('-h', '--help', 'Show this message') do
        puts opts
        exit
      end
    end
    begin
      opts.parse!(args)
      options
    rescue OptionParser::InvalidOption => e
      puts e
      puts opts
      exit(1)
    end
  end
end

class TSMonitor
  def initialize(options)
    @options  = options
    @plugin_name = options.instance.nil? ? 'teamspeak3' : "teamspeak3-#{options.instance}"
    @hostname = `hostname -f`.strip
    @parent_pid = `ps -p #{Process.pid} -o ppid=`.delete(' ').to_i
    @values = { 'virtualserver_clientsonline' => 'gauge',
                'connection_bytes_sent_total' => 'derive',
                'connection_bytes_received_total' => 'derive'
              }
  end

  # Execute the get and priont value function every x seconds
  def run
    loop do
      start_time = Time.now.to_i
      ts = Teamspeak::Client.new(@options.host, @options.port)
      ts.login(@options.user, @options.password) unless @options.user.nil?
      ts.command('use', 'sid' => 1)
      serverinfo = ts.command('serverinfo')
      ts.disconnect
      @values.each do |k, v|
        puts "PUTVAL \"#{@hostname}/#{@plugin_name}/#{v}-#{k}\" interval=#{@options.wait} #{start_time}:#{serverinfo[k.to_s]}"
      end
      exit 0 unless Process.getpgid(@parent_pid)
      elapsed_time = Time.now.to_i - start_time
      puts "PUTVAL \"#{@hostname}/#{@plugin_name}/gauge-check_duration\" interval=#{@options.wait} #{start_time}:#{elapsed_time}"
      waittime = (elapsed_time < @options.wait) ? (@options.wait - elapsed_time) : @options.wait
      sleep(waittime)
    end
  end
end

$stdout.sync = true

options = Optparser.parse(ARGV)

tsmonitor = TSMonitor.new(options)
tsmonitor.run
