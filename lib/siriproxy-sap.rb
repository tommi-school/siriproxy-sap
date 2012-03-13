require 'cora'
require 'siri_objects'
require 'pp'
require 'json'
require 'httparty'
require 'nokogiri'
require 'open-uri'


class SiriProxy::Plugin::Sap < SiriProxy::Plugin
	def initialize(config)
		# Instance Variables
 		@sapgw_hostname = "http://gw.esworkplace.sap.com/"
		#Acct Variables (Stored globally so that in the event a user makes a second request
		# pertaining to an account we dont need to refetch the data.
		@acc_no = ""
		@acc_name = ""
		@acc_cat = ""
		@acc_addr_no = ""
		@acc_addr_street = ""
		@acc_addr_city = ""
		@acc_addr_region = ""
		@acc_addr_country = ""
		@acc_addr_zip = ""
		@acc_website = ""
		@acc_email = ""
	end


	def test_connection
		#We simply fetching some data from a gateway call to ensure the system responds
		#If you are using your own gateway box, I suggest connecting to
		uri = "#{@sapgw_hostname}sap/opu/sdata/sap/DEMO_FLIGHT/z_demo_flightCollection(value=%27020408_DL198420090413%27,scheme_id=%27Z_DEMO_FLIGHT%27,scheme_agency_id=%27HU2_800%27)"
		doc = Nokogiri::HTML(open(uri))
		puts "Opened URL"
		
		@response = "Connection error"

		doc.xpath('//scheme_agency_id').each do |value|
			@response = value.content
		end
		@response = "SAP Server: " + @sapgw_hostname + "<br />Company: " + @response
   		return @response
	end


	def show_account(acctno)
		uri = "#{@sapgw_hostname}sap/opu/sdata/iwcnt/account/AccountCollection(Value=%27" + acctno +"%27,Scheme_ID=%27ACCOUNT%27,Scheme_Agency_ID=%27HU4_800%27)"
		doc = Nokogiri::HTML(open(uri))
		puts "Opened URL " + uri
		
		doc.xpath('//value').each do |acc_no1|
			@acc_no = acc_no1.content
		end
		doc.xpath('//categorytext').each do |acc_cat1|
			@acc_cat = acc_cat1.content
		end
		doc.xpath('//organizationname').each do |acc_name1|
			@acc_name = acc_name1.content
		end
		doc.xpath('//houseid').each do |acc_addr_no1|
			@acc_addr_no = acc_addr_no1.content
		end
		doc.xpath('//street').each do |acc_addr_street1|
			@acc_addr_street = acc_addr_street1.content
		end
		doc.xpath('//city').each do |acc_addr_city1|
			@acc_addr_city = acc_addr_city1.content
		end
		doc.xpath('//countryname').each do |acc_addr_country1|
			@acc_addr_country = acc_addr_country1.content
		end
		doc.xpath('//citypostalcode').each do |acc_addr_zip1|
			@acc_addr_zip = acc_addr_zip1.content
		end
		doc.xpath('//regionname').each do |acc_addr_region1|
			@acc_addr_region = acc_addr_region1.content
		end
		doc.xpath('//uri').each do |acc_website1|
			@acc_website = acc_website1.content
		end
		doc.xpath('//email').each do |acc_email1|
			@acc_email = acc_email1.content
		end

		object = SiriAddViews.new
		object.make_root(last_ref_id)

		puts "read file"

		answer = SiriAnswer.new("Account:" + @acc_no, [SiriAnswerLine.new('logo','http://li-labs.com/images/Siri.png'),
		
		SiriAnswerLine.new(@acc_name),
		SiriAnswerLine.new(@acc_cat),
   		SiriAnswerLine.new("--------------------------------------"),
 		
		SiriAnswerLine.new(@acc_email),
		SiriAnswerLine.new(@acc_website),
   		SiriAnswerLine.new("--------------------------------------"),

		SiriAnswerLine.new(@acc_addr_no + " " + @acc_addr_street),
		SiriAnswerLine.new(@acc_addr_city + ", " + @acc_addr_country),
		SiriAnswerLine.new(@acc_addr_zip + " " + @acc_addr_region)
		])

    		object.views << SiriAnswerSnippet.new([answer])
		send_object object
	end

	def show_account_name(acctno)
		uri = "#{@sapgw_hostname}sap/opu/sdata/iwcnt/account/AccountCollection(Value=%27" + acctno + "%27,Scheme_ID=%27ACCOUNT%27,Scheme_Agency_ID=%27HU4_800%27)"
		doc = Nokogiri::HTML(open(uri))
		puts "Opened URL " + uri

		@acc_no = acctno
		
		doc.xpath('//categorytext').each do |acc_cat1|
			@acc_cat = acc_cat1.content
		end
		
		doc.xpath('//organizationname').each do |acc_name1|
			@acc_name = acc_name1.content
		end

		say "The account name is " + @acc_name + " and it looks like its a " + @acc_cat

	end


	def show_map (object_name)
		#Method does not work correctly
		add_views = SiriAddViews.new
		add_views.make_root(last_ref_id)
		map_snippet = SiriMapItemSnippet.new
		#map_snippet.items << SiriMapItem.new
		siri_location = SiriLocation.new(@acc_name, @acc_addr_no + " " + @acc_addr_street, @acc_addr_city, @acc_addr_region,
        @acc_addr_country, @acc_addr_zip)
		map_snippet.items << SiriMapItem.new(@acc_name, siri_location, "FRIEND_ITEM")
		add_views.views << map_snippet
    
		send_object add_views
	end

	#Listeners section

	listen_for /test connection/i do
		say "Testing, one moment please"
    
		Thread.new {
			t = test_connection
			object = SiriAddViews.new
			object.make_root(last_ref_id)
			say "Connection to SAP is succesful"
			answer = SiriAnswer.new(t)
			object.views << SiriAnswerSnippet.new([answer])
			send_object object

			request_completed
		}
	end

	listen_for /(open|show) (account|company) details/i do
		response = "no"
		if (@acc_no)
			response = ask "For " + @acc_name + "?"	
		end
		
		if (response =~ /yes/i)
			acctno = @acc_no
		else		
			acctno = ask "OK, for which account?" #ask the user for account number
			acctno.strip!
    		end

		say "Opening account: " + acctno + " ", spoken: "Opening account"

		if (acctno) #process their response
			Thread.new {
				show_account(acctno)
				request_completed
			}
		end
	end

	listen_for /show map for (.*)/i do | accntname |
		say "OK, I will check for you"
		Thread.new {
			acctname.strip!
			show_map (object_name)
			request_completed
		}
		
	end
								
	listen_for /(show|what) account name/i do
		acctno = ask "OK, for which account number?" #ask the user for account number
		say "Checking account: " + acctno, spoken: "Checking"

		Thread.new {
			acctno.strip!
			show_account_name (acctno)

			request_completed
		}
	end


	listen_for /show sales data for (.*)/i do
		say "My name is Siri, not HANA."
	end
end
