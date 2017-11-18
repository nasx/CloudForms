=begin
  create_host.rb
  Author: Chris Keller <ckeller@redhat.com
  Description: This method will create a host in IdM and generate/assign an OTP
               for provisioning.
-------------------------------------------------------------------------------
   Copyright 2017 Chris Keller <ckeller@redhat.com>

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-------------------------------------------------------------------------------
=end

require 'net/http'
require 'openssl'
require 'uri'
require 'json'
require 'securerandom'

begin
    prov = $evm.root['miq_provision']
  
    api_password = $evm.object.decrypt('password')
    api_username = $evm.object['username']
    api_hostname = $evm.object['hostname']
   
  	host_ip = prov.get_option(:ip_addr)
  	vm_name = prov.get_option(:vm_name)
  
    host_name = ""
    host_dns = ""
	  	
    # Expecting an FQDN here...extract hostname/domainname from vm_name
  	# Note: host_dns will end up w/ an extra . at the end; this is required for host_add, not host_mod
  
    if vm_name.include? "."
        host_name = (split = vm_name.split(".")).shift
       	split.each { |s| host_dns << "#{s}." }
    else
        $evm.log(:info, "When using create_host you must assign vm_name (#{vm_name}) an FQDN!")
       	exit MIQ_ERROR
    end
  
    # Generate OTP using SecureRandom
  
    host_otp = SecureRandom.hex
  	$evm.log(:info, "host_otp = #{host_otp}")

    # First we need to get our ipa_session cookie

    url = "https://#{api_hostname}/ipa"
    uri = URI.parse("#{url}/session/login_password")

    request = Net::HTTP::Post.new(uri)
  	request["Referer"] = url
    request["Accept"] = "text/plain"
    request.content_type = "application/x-www-form-urlencoded"
    request.set_form_data("user" => "#{api_username}", "password" => "#{api_password}")

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
        http.request(request)
    end

    if(response.code != '200')
        $evm.log(:error, "Response Code: #{response.code}")
        $evm.log(:error, response.to_hash)

        exit MIQ_ERROR
    end

    cookies = response.get_fields('set-cookie')[0].split(";")
    ipa_session = cookies[0].split("=")[1]

  	# Submit JSON request for host_add

    uri = URI.parse("#{url}/session/json")
    hash = {:method=>"host_add", :params=>[["#{host_name}.#{host_dns}"], {:ip_address=>host_ip}]}

    request = Net::HTTP::Post.new(uri)
    request["Referer"] = url
    request["Accept"] = "application/json"
    request["Cookie"] = "ipa_session=#{ipa_session}"
    request.content_type = "application/json"
    request.body = hash.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
        http.request(request)
    end

    if(response.code != '200')
        $evm.log(:error, "Response Code: #{response.code}")
        $evm.log(:error, response.to_hash)

        exit MIQ_ERROR
    end

    # Submit JSON request for host_mod (set OTP)

    uri = URI.parse("#{url}/session/json")
    hash = {:method=>"host_mod", :params=>[["#{host_name}.#{host_dns.chomp('.')}"], {:userpassword=>host_otp}]}

    request = Net::HTTP::Post.new(uri)
    request["Referer"] = url
    request["Accept"] = "application/json"
    request["Cookie"] = "ipa_session=#{ipa_session}"
	request.content_type = "application/json"
    request.body = hash.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
        http.request(request)
    end

    if(response.code != '200')
        $evm.log(:error, "Response Code: #{response.code}")
        $evm.log(:error, response.to_hash)

        exit MIQ_ERROR
    end
  
	# Everything was successful, set ws_values to include OTP for use in cloud-init template
  	
  	ws_values = prov.options.fetch(:ws_values, {})
  	ws_values[:otp] = host_otp
  
  	prov.set_option(:ws_values, ws_values) 
end
