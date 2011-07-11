#!/usr/bin/env ruby

# encoding: UTF-8
$KCODE = 'UTF8' unless RUBY_VERSION >= '1.9'
require 'lib/klastfm'

if __FILE__ == $0
  t = Time.now

  klastfm = Klastfm.new
  klastfm.get_all_tracks

  Statistic.transaction do
    klastfm.create_statistics
    klastfm.score_tracks
    klastfm.date_tracks
    klastfm.save_statistic!
  end

  #Tagging.transaction do
  #  Tag.transaction do
  #    klastfm.tag_tracks
  #    klastfm.save_tags!
  #  end
  #end

  puts "Runtime: #{((Time.now-t)/60).to_i} minutes"
else
  puts "please read the README.rdoc"
end
