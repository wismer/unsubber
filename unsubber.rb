require 'net/imap'
require 'pry'
require 'nokogiri'
require 'sequel'


module Unsubber
  DB = Sequel.connect('sqlite://unsubber.db')

  class Email < Sequel::Model; end

  def self.login(login_info)
    user, pass = login_info
    email = Net::IMAP.new('imap.gmail.com', { :port => 993, :ssl => true } )
    email.login(user, pass)
    email.select('Inbox')
    unsub = Unsub.new(email)
    # unsub.get_unsub_links
    unsub.list_sources
    binding.pry
    # unsub.a_tags
  end

  class Unsub
    attr_reader :access, :record
    def initialize(access)
      @access = access
      @record = {}
    end

    def list_sources
      read_email.each do |mail|
  
        site = envelope(mail).first.attr["ENVELOPE"].from[0].host
        if site
          site_key = site.gsub(/\.\w+$/, '').gsub(/\./, '_').to_sym
          puts "key: #{site_key} uid: #{mail}"
          Email.insert(host_dns: site, u_id: mail)
          # if @record[site_key]
          #   @record[site_key][:count] += 1
          #   @record[site_key][:uid] << mail
          # else
          #   @record[site_key] = { :site => site, :count => 1, :uid => [mail] }
          # end
        end
      end       
    end

    def new_email
      @access.search(["NEW"])
    end

    def read_email
      @access.search(["NOT", "NEW"])[-500..-1]
    end

    def envelope(mail)
      @access.fetch(mail, "ENVELOPE")
    end

    def body_tag(tag)
      @access.fetch(tag, "BODY[TEXT]")[0].attr['BODY[TEXT]']
    end

    def get_unsub_links
      puts "#{new_email.size} NEW"
      puts "#{read_email.size} READ"
      emails = read_email[-10..-1]
      # convert to html text
      emails.each do |email|
        raw_html = body_tag(email)
        if raw_html =~ /unsubscr/
          parsed_html = parse_html(raw_html)
          parsed_html.search('a').each do |a|
            puts a if a.children.text =~ /unsubs/
          end
        end
      end
    end

    def parse_html(raw_html)
      Nokogiri::HTML::Document.parse(raw_html)
    end
  end
end

Unsubber.login ARGV