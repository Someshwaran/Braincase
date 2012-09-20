# encoding: utf-8

$LOAD_PATH.unshift(File.dirname("/usr/share/braincase/lib/braincase"))

require 'yaml'
require 'braincase/utils'
require 'braincase/user'

$conf = Braincase.config
$user = Braincase.current_user
$date = Time.new.strftime("%Y.%m.%d.%H.%M:%S")

##
# Backup Generated: daily_backup
# Once configured, you can run the backup with the following command:
#
# $ backup perform -t daily_backup [-c <path_to_configuration_file>]
#
Backup::Model.new(:daily_backup, "Daily Braincase backup for #{$user.name}") do
  ##
  # Split [Splitter]
  #
  # Split the backup file in to chunks of 250 megabytes
  # if the backup file size exceeds 250 megabytes
  #
  split_into_chunks_of 250
  ##
  # Archive [Archive]
  #
  # Adding a file:
  #
  #  archive.add "/path/to/a/file.rb"
  #
  # Adding an directory (including sub-directories):
  #
  #  archive.add "/path/to/a/directory/"
  #
  # Excluding a file:
  #
  #  archive.exclude "/path/to/an/excluded_file.rb"
  #
  # Excluding a directory (including sub-directories):
  #
  #  archive.exclude "/path/to/an/excluded_directory/
  #
  archive :dokuwiki do |a|
    a.add "#{$conf[:data_dir]}/pages/#{$user.name}"
    a.add "#{$conf[:data_dir]}/meta/#{$user.name}"
    a.add "#{$conf[:data_dir]}/attic/#{$user.name}"
    a.options "--index-file=~/backups/daily_backup/#{$date}/dokuwiki_manifest.txt"
  end

  archive :home do |a|
    a.add "~"
    a.exclude "~/#{$user.name}.git"
    a.options "--index-file=~/backups/daily_backup/#{$date}/home_manifest.txt"
  end

  archive :repo do |a|
    a.add "~/#{$user.name}.git"
    a.options "--index-file=~/backups/daily_backup/#{$date}/repo_manifest.txt"
  end

  ##
  # Local (Copy) [Storage]
  #
  store_with Local do |local|
    local.path       = "~/backups/"
    local.keep       = 14
  end

  ##
  # Gzip [Compressor]
  #
  compress_with Gzip

  ##
  # Mail [Notifier]
  #
  # The default delivery method for Mail Notifiers is 'SMTP'.
  # See the Wiki for other delivery options.
  # https://github.com/meskyanichi/backup/wiki/Notifiers
  #
  notify_by Mail do |mail|
    mail.on_success           = true
    mail.on_warning           = true
    mail.on_failure           = true

    mail.from                 = $conf[:email][:from]
    mail.to                   = $user.email
    mail.address              = $conf[:email][:address]
    mail.port                 = $conf[:email][:port]
    mail.domain               = $conf[:email][:domain]
    mail.user_name            = $conf[:email][:user_name]
    mail.password             = $conf[:email][:password]
    mail.authentication       = $conf[:email][:authentication]
    mail.enable_starttls_auto = true
  end

end