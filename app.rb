# encoding: utf-8

require 'bundler'
Bundler.require
Dotenv.load
require 'pathname'
require 'oj'

class App < Thor

  def initialize(*args) # {{{
    super
    connect_database
  end # }}}

  desc 'list', 'List all mail account'
  method_option :format, aliases: :f, required: true, default: :human, enum: %w`human json`, desc: 'Format to output'
  def list # {{{
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
  end # }}}

  desc 'add', 'Add new email account'
  method_option :email, aliases: :e, required: true, desc: 'e-mail address you want to create.'
  method_option :password, aliases: :p, required: true, desc: 'Password to access IMAP/SMTP server.'
  def add # {{{
    account, domain = options[:email].match(/(.+)@(.+)/){|m|[m[1],m[2]]}

    # Validation
    unless account && domain
      puts %`"#{options[:email]}" is not valid email address.`
      exit 1
    end

    # Existence check
    if Mailbox.first(username: options[:email]) && Alias.first(address: options[:email])
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
    mailbox = Mailbox.first_or_create({
      username: options[:email],
    },
    {
      username: options[:email],
      password: cram_md5(options[:password]),
      name: options[:email],
      maildir: File.expand_path(mailbox_account_dir).sub(%r`^#{File.expand_path(base_dir)}/`, '') + '/',
      local_part: account,
      domain: domain,
      created: DateTime.now,
      modified: DateTime.now
    })

    # Create alias
    mail_alias = Alias.first_or_create({
      address: options[:email],
    },
    {
      address: options[:email],
      goto: options[:email],
      domain: domain,
      created: DateTime.now,
      modified: DateTime.now
    })

    if mailbox.save && mail_alias.save && mailbox_sub_dirs.all?{|dir| File.exists? dir }
      puts "Mailbox successfully created."
    else
      puts "Failed to create a mailbox."
      exit 1
    end
  end # }}}

  desc 'passwd', 'Change mailbox password'
  method_option :email, aliases: :e, required: true, desc: 'e-mail address you want to change password.'
  method_option :password, aliases: :p, required: true, desc: 'New password'
  def passwd # {{{
    mailbox = Mailbox.first(username: options[:email])

    unless mailbox
      puts "Mailbox doesn't exists"
      exit 1
    end

    if mailbox.update(password: cram_md5(options[:password]))
      puts "Password changed."
    else
      puts "Failed to change password"
      exit 1
    end
  end # }}}

  desc 'delete', 'Delete mailbox'
  method_option :email, aliases: :e, required: true, desc: 'e-mail address you want yo delete.'
  def delete # {{{
    account, domain = options[:email].match(/(.+)@(.+)/){|m|[m[1],m[2]]}
    mailbox = Mailbox.first(username: options[:email])
    mail_alias = Alias.first(address: options[:email])

    unless mailbox
      puts "Mailbox doesn't exists"
      exit 1
    end

    if mailbox.destroy
      puts "Mailbox destroyed"
    else
      puts "Failed to destroy mailbox."
      exit 1
    end

    unless mail_alias
      puts "Mailbox alias doesn't exists"
      exit 1
    end

    if mail_alias.destroy
      puts "Mailbox alias destroyed"
    else
      puts "Failed to destroy mailbox alias."
      exit 1
    end

    base_dir = Pathname.new(ENV['MAILBOX_BASEDIR'] || './mailboxes')
    mailbox_domain_dir = base_dir + domain
    mailbox_account_dir = base_dir + domain + account

    archive_dir = Pathname.new(ENV['MAILBOX_ARCHIVEDIR'] || './mailbox_archives')
    archive_domain_dir = archive_dir + domain
    archive_account_dir = archive_dir + domain + "#{account}_#{DateTime.now.strftime("%Y-%m-%d-%H-%M-%S")}"

    unless File.exists? mailbox_account_dir
      puts %`"#{mailbox_account_dir}" not exists.`
      exit 1
    end

    unless File.exists? archive_dir
      puts "Create #{archive_dir}"
      Dir.mkdir archive_dir, 0700
    end

    unless File.exists? archive_domain_dir
      puts "Create #{archive_domain_dir}"
      Dir.mkdir archive_domain_dir, 0700
    end

    if FileUtils.move mailbox_account_dir, archive_account_dir
      puts "Move #{mailbox_account_dir} to #{archive_account_dir}"
    else
      puts "Failed to move #{mailbox_account_dir} to #{archive_account_dir}"
      exit 1
    end

  end # }}}

  private
  def connect_database # {{{
    require './models'
    DataMapper.finalize.auto_upgrade!
  end # }}}

  def cram_md5 password # {{{
    "{CRAM-MD5}" + DovecotCrammd5.calc(password)
  end # }}}

end

App.start ARGV
