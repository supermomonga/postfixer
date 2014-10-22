# encoding: utf-8

require 'bundler'
Bundler.require
Dotenv.load
require 'pathname'
require 'oj'

class App < Thor

  def initialize(*args)
    super
    connect_database
  end

  desc 'list', 'List all mail account'
  method_option :format, aliases: :f, required: true, default: :human, enum: %w`human json`, desc: 'Format to output'
  def list
    mailboxes = Mailbox.all

    case options[:format].to_sym
    when :human
      puts "Found #{mailboxes.size} mailboxes."
      mailboxes.each do |mailbox|
        puts "#{mailbox.username}\t\t(created at #{mailbox.created.strftime '%F %T'})"
      end
    when :json
      json = Oj.dump mailboxes.map{|mailbox|
        %i`username name maildir local_part domain created modified`.each_with_object({}){|row, acc|
          acc[row] = mailbox.send row
        }
      }
      puts json
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
        description: domain,
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
    mailbox_sub_dirs = %w`cur new tmp`.map{|dir|
      mailbox_account_dir + dir
    }

    unless File.exists? mailbox_domain_dir
      puts "Create #{mailbox_domain_dir}"
      Dir.mkdir mailbox_domain_dir, 0700
    end

    unless File.exists? mailbox_account_dir
      puts "Create #{mailbox_account_dir}"
      Dir.mkdir mailbox_account_dir, 0700
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
      password: DovecotCrammd5.calc(options[:password]),
      name: options[:email],
      maildir: "{CRAM-MD5}" + File.expand_path(mailbox_account_dir),
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
