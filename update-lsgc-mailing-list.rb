#!/usr/bin/env ruby
=begin licence
Copyright (c) 2011, Romain Tartiere. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
=end

=begin description
Synchronise OVH hosted mailing-list members from the VO user list provided by a
VOMS.
=end

#require 'rubygems'
#require 'http-access2'
#require 'pp'
require 'optparse'
require 'soap/wsdlDriver'

options = {
  :force        => false,
  :vo           => 'biomed',
  :voms         => 'voms-biomed.in2p3.fr',
  :ovh_nic      => 'LE14-OVH',
  :ovh_password => nil,
  :mailing_list => nil,
  :sync         => true,
  :extra_moderators => [],
}

OptionParser.new do |opts|
  opts.banner = "usage: #{$0} [options]"
  opts.separator ""
  opts.separator "Virtual Organisation (VO) options:"
  opts.on("-h", "--host=HOST", "Connect to HOST VOMS server") do |host|
    options[:voms] = host
  end
  opts.on("-v", "--vo=VO", "Get addresses for VO") do |vo|
    options[:vo] = vo
  end
  opts.separator ""
  opts.separator "Mailing-List options:"
  opts.on("-D", "--ovh-nic=NIC", "Use NIC as OVH nic-handle") do |nic|
    options[:ovh_nic] = nic
  end
  opts.on("-w", "--ovh-password=PASSWORD", "Use PASSWORD as OVH password (insecure)") do |password|
    options[:ovh_password] = password
  end
  opts.on("-W=FILENAME", "Read  password from FILENAME (more secure)") do |filename|
    options[:ovh_password] = File.read(filename)
  end
  opts.on("-m", "--mailing-list=LIST", "Update the LIST mailing-list") do |list|
    options[:mailing_list] = list
  end
  opts.on("-M", "--moderator=EMAIL", "Unconditionaly set EMAIL as moderator") do |email|
    options[:extra_moderators] += [ email ]
  end
  opts.separator ""
  opts.separator "Misc options:"
  opts.on("-s", "--[no-]sync", "Synchronize mailing-list from VOMS (default)") do |sync|
    options[:sync] = sync
  end
  opts.on("-f", "--force", "Force operation") do
    options[:force] = true
  end
end.parse!

# If no password was provided, derivate login to password filename
if options[:ovh_password].nil? then
  options[:ovh_password] = File.read("#{ENV['HOME']}/.#{options[:ovh_nic].downcase}")
end

if options[:mailing_list].nil? then
  options[:mailing_list] = "lsgc-#{options[:vo].downcase}-users@healthgrid.org"
end

# Hack to check remote server certificate
class Net::HTTP
  alias_method :old_initialize, :initialize

=begin
  def initialize(*args)
    old_initialize(*args)
    @ssl_context = OpenSSL::SSL::SSLContext.new
    @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
=end

  def initialize(*args)
    old_initialize(*args)
    @ssl_context = OpenSSL::SSL::SSLContext.new
    @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
    @ssl_context.ca_file = '/etc/pki/tls/certs/ca-bundle.crt'
  end
end

class MailingList
  attr_accessor :name, :domain, :subscribers, :moderators, :additions, :removals, :aadditions, :aremovals

  def initialize(soapi, session, address, extra_moderators)
    @soapi, @session = soapi, session
    @name, @domain = address.split('@')
    info = soapi.mailingListFullInfo(session, domain, name)
    @subscribers = info.subscribers
    @moderators = info.moderators
    @additions = @removals = @aadditions = @aremovals = 0
  end

  def to_s
    "#{name}@#{domain}"
  end

  def subscribe(address)
    try_again = true
    while try_again do
      begin
        try_again = false
        @soapi.mailingListSubscriberAdd(@session, domain, name, address)
      rescue => e
        try_again = e.message == "A mailing list task is still in progress for : #{self}"
	if try_again then
          sleep(10)
        else
          raise e
        end
      end
    end
    @subscribers += [address]
    @additions += 1
  end

  def unsubscribe(address)
    try_again = true
    while try_again do
      begin
        try_again = false
        @soapi.mailingListSubscriberDel(@session, domain, name, address)
      rescue => e
        try_again = e.message == "A mailing list task is still in progress for : #{self}"
	if try_again then
          sleep(10)
        else
          raise e
        end
      end
    end
    @subscribers -= [address]
    @removals += 1
  end

  def add_moderator(address)
    try_again = true
    while try_again do
      begin
        try_again = false
        @soapi.mailingListModeratorAdd(@session, domain, name, address)
      rescue => e
        try_again = e.message == "A mailing list task is still in progress for : #{self}"
	if try_again then
          sleep(10)
        else
          raise e
        end
      end
    end
    @moderators += [address]
    @aadditions += 1
  end

  def del_moderator(address)
    try_again = true
    while try_again do
      begin
        try_again = false
        @soapi.mailingListModeratorDel(@session, domain, name, address)
      rescue => e
        try_again = e.message == "A mailing list task is still in progress for : #{self}"
	if try_again then
          sleep(10)
        else
          raise e
        end
      end
    end
    @moderators -= [address]
    @aremovals += 1
  end
end

if options[:sync] then
  wsdl = 'https://www.ovh.com/soapi/soapi-re-1.20.wsdl'
  wsdl = '/root/lib/ovh/soapi-re-1.20.wsdl'
  soapi = SOAP::WSDLDriverFactory.new(wsdl).create_rpc_driver

  session = soapi.login(options[:ovh_nic], options[:ovh_password], 'en', false)

  mailing_list = MailingList.new(soapi, session, options[:mailing_list], options[:extra_moderators])

  puts "Updating #{mailing_list} with information from VO #{options[:vo].upcase} (using #{options[:voms]})"
end

users = `/usr/bin/env GLITE_LOCATION="/opt/glite" /usr/bin/voms-admin --vo="#{options[:vo]}" --host="#{options[:voms]}" list-users | sed -e 's|.* - ||'`.downcase.split("\n").uniq

if $?.exitstatus != 0 then
  puts %(  **ERROR** voms-admin --vo="#{options[:vo]}" --host="#{options[:voms]}" list-users" returned #{$?.exitstatus})
  exit 1
end

if !options[:sync] then
  users.each { |user| puts user }
  exit 0
end

moderators = `/usr/bin/env GLITE_LOCATION="/opt/glite" /usr/bin/voms-admin --vo="#{options[:vo]}" --host="#{options[:voms]}" list-users-with-role "/#{options[:vo]}" "Role=VO-Admin" | sed -e 's|.* - ||'`.downcase.split("\n").uniq

if $?.exitstatus != 0 then
  puts %(  **ERROR** voms-admin --vo="#{options[:vo]}" --host="#{options[:voms]}" list-users-with-role "/#{options[:vo]}" returned #{$?.exitstatus})
  exit 1
end

# no Array.select!  ?!
moderators = moderators.select { |x|  /.*@.*/ =~ x }

if moderators.length == 0 then
  puts "  **WARNING** It looks like we can not list-users-with-role /#{options[:vo]} Role=VO-Admin"
end
moderators += options[:extra_moderators]


if (users.length - mailing_list.subscribers.length) < -20 then
  puts "It looks like we should remove #{users.length - mailing_list.subscribers.length} users."
  if !options[:force] then
    puts "If this is supposed to happend, use the --force argument"
    exit 1
  end
end

begin
	users.each do |user|
		if !mailing_list.subscribers.include?(user) then
			puts "+ #{user}"
			mailing_list.subscribe(user)
		end
	end

	mailing_list.subscribers.each do |subscriber|
		if !users.include?(subscriber) then
			puts "- #{subscriber}"
			mailing_list.unsubscribe(subscriber)
		end
	end

	moderators.each do |moderator|
		if !mailing_list.moderators.include?(moderator) then
			puts "+ #{moderator}!"
			mailing_list.add_moderator(moderator)
		end
	end

	mailing_list.moderators.each do |moderator|
		if !moderators.include?(moderator) then
			puts "- #{moderator}!"
			mailing_list.del_moderator(moderator)
		end
	end
rescue => e
  puts "Exception raised: \"#{e.message}\""
  puts e.backtrace
ensure
  puts
  puts "Number of subscribers: #{mailing_list.subscribers.length} (+#{mailing_list.additions}, -#{mailing_list.removals})"
  puts "Number of moderators: #{mailing_list.moderators.length} (+#{mailing_list.aadditions}, -#{mailing_list.aremovals})"
  puts
end
