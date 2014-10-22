# encoding: utf-8

require 'bundler'
Bundler.require
Dotenv.load
require 'pathname'

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
      puts "#{mailbox.username}\t(#{mailbox.created} created.)"
    end
  end

  desc 'add', 'Add new email account'
  method_option :email, aliases: :e, required: true, desc: 'e-mail address you want yo create.'
  method_option :password, aliases: :p, required: true, desc: 'Password to access IMAP/SMTP server.'
  def add
    account, domain = options[:email].match(/(.+)@(.+)/){|m|[m[1],m[2]]}

    # Validation
    unless account && domain
      puts %`"#{options[:email]}" is not valid email address.`
      exit 1
    end

    # Existence check
    if Mailbox.first(username: options[:email])
      puts "Already exists."
      exit 1
    end

    # Create domain if not exists
    unless Domain.first(domain: domain) || Domain.create({
        domain: domain,
        description: "#{options[:email]}",
        created: DateTime.now,
        modified: DateTime.now
      }).save
      puts "Failed to create domain."
      exit 1
    end

    base_dir = Pathname.new(ENV['MAILBOX_BASEDIR'] || './mailboxes')

    # Existence check of base directory
    unless File.exists? base_dir
      puts %`"#{base_dir}" not exists.`
      exit 1
    end

    mailbox_domain_dir = base_dir + domain
    mailbox_account_dir = base_dir + domain + account

    unless File.exists? mailbox_domain_dir
      puts "Create #{mailbox_domain_dir}"
      Dir.mkdir mailbox_domain_dir, 0700
    end

    unless File.exists? mailbox_account_dir
      puts "Create #{mailbox_account_dir}"
      Dir.mkdir mailbox_account_dir, 0700
      mailbox_sub_dirs = %w`cur new tmp`.map{|dir|
        mailbox_account_dir + dir
      }
      mailbox_sub_dirs.each do |mailbox_sub_dir|
        unless File.exists? mailbox_sub_dir
          puts "Create #{mailbox_sub_dir}"
          Dir.mkdir mailbox_sub_dir, 0700 
        end
      end
    end

    # Create mailbox
    mailbox = Mailbox.create({
      username: options[:email],
      password: options[:password],
      name: options[:email],
      maildir: File.expand_path(mailbox_account_dir),
      local_part: account,
      domain: domain,
      created: DateTime.now,
      modified: DateTime.now
    })

    if mailbox.save && mailbox_sub_dirs.all?{|dir| File.exists? dir }
      puts "Mailbox successfully created."
    else
      puts "Failed to create a mailbox."
      exit 1
    end

  end

  private
  def connect_database
    require './models'
    DataMapper.finalize.auto_upgrade!
  end

end

App.start ARGV
