class Klastfm
  require 'rubygems'
  require 'yaml'
  require 'active_record'
  require 'logger'
  require 'progressbar'

  require 'lib/models'

  def initialize
    begin
      config = YAML.load_file('config/config.yaml')
    rescue Errno::ENOENT
      raise 'config/config.yaml not found'
    end

    Dir.mkdir('log') unless File.exists?('log')
    ActiveRecord::Base.establish_connection(config['mysql'].merge({:adapter => 'mysql', :encoding => 'utf8'}))
    ActiveRecord::Base.logger = Logger.new('log/database.log')

    # just a random request to check if everything is ok
    # anyone knows how to test the db-connection?
    begin
      Track.first
    rescue Mysql::Error
      raise 'Cannot connect to the database. Check config/config.yaml'
    end

    @all_tracks = nil
    @pages = nil
  end

  def get_all_tracks
    @all_tracks = {}
    File.open('log/not_found.log', 'w') { |file| file.write("These tracks were not found in your Amarok collection:\n\n") }
    lines = File.open('data/exported_tracks.txt').readlines#[0..1000]
    puts "processing #{lines.size} tracks"
    bar = ProgressBar.new('processing', lines.size)

    lines.each do |line|
      bar.inc
      time, title, artist = line.split("\t")
      time = time.to_i
      begin
        url = Track.url_of(artist, title)
        unless url
          File.open('log/not_found.log', 'a') { |file| file.write("#{artist} - #{title}\n") }
          next
        end

        if @all_tracks[url]
          @all_tracks[url][:playcount] = @all_tracks[url][:playcount]+1
          @all_tracks[url][:accessdate] = (time > @all_tracks[url][:accessdate] ? time : @all_tracks[url][:accessdate])
          @all_tracks[url][:createdate] = (time < @all_tracks[url][:createdate] ? time : @all_tracks[url][:createdate])
        else
          @all_tracks[url] = {
                  :artist => artist,
                  :title => title,
                  :playcount => 1,
                  :accessdate => time,
                  :createdate => time
          }
        end
      rescue
        puts "error with track #{artist} - #{title}"
      end
    end
    bar.finish && puts
    puts "#{lines.size} tracks processed, some were not found in your Amarok collection (details in file: data/not_found.log)"
    @all_tracks
  end

  def save_statistic!
    puts "save the statistics to database"
    bar = ProgressBar.new('saving', @all_tracks.size)
    @all_tracks.each do |url, track|
      statistic = Statistic.find_by_url(url)
      unless statistic
        puts "Statistic not found: #{url} - #{track[:artist]} - #{track[:title]} - #{Time.at(track[:createdate])} - #{Time.at(track[:accessdate])}"
        next
      end

      #puts "#{url}: #{track[:artist]} - #{track[:title]} - #{Time.at(track[:createdate])} - #{Time.at(track[:accessdate])}"
      statistic.update_attributes(
              :playcount => track[:playcount],
              :accessdate => track[:accessdate],
              :createdate => track[:createdate]
      )
      bar.inc
    end
    bar.finish && puts
  end
end
