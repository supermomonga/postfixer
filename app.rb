# encoding: utf-8

require 'bundler'
Bundler.require


class App < Thor

  def initialize(*args)
    super
    connect_database
  end

  desc 'list', 'List all mail account'
  def list
    count = Mailbox.count
    puts "Found #{count} mailboxes."
    Mailbox.all.map do |mailbox|
      puts mailbox.username
    end
  end

  private
  def connect_database
    require './models'
    DataMapper.finalize.auto_upgrade!
  end

end

App.start ARGV
