=begin
  list_groups.rb
  Author: Chris Keller <ckeller@redhat.com
  Description: This method will list user groups managed by IdM
-------------------------------------------------------------------------------
   Copyright 2016 Chris Keller <ckeller@redhat.com>

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

begin
  
  password = $evm.object.decrypt('password')
  username = $evm.object['username']
  hostname = $evm.object['hostname']

  # First we need to get our ipa_session cookie

  url = "https://#{hostname}/ipa"
  uri = URI.parse("#{url}/session/login_password")

  request = Net::HTTP::Post.new(uri)
  request["Referer"] = url
  request["Accept"] = "text/plain"
  request.content_type = "application/x-www-form-urlencoded"
  request.set_form_data("user" => "#{username}", "password" => "#{password}")

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

  # Submit JSON request for group_find & build our subsequent batch request for GIDs

  uri = URI.parse("#{url}/session/json")
  hash = {:method=>"group_find", :params=>[[""], {:pkey_only=>true, :sizelimit=>0}]}

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
  
  json_data = JSON.parse(response.body)
  group_list = {}
  
  json_data['result']['result'].each do |group|
    group_list[group['cn'][0]] = group['cn'][0]
    $evm.log(:info, "DEBUG: Group Found: #{group['cn'][0]}")
  end
    
  list_values = {
    'sort_by' => :value,
    'required' => false,
    'default_value' => 'false',
    'values' => group_list
  }

  $evm.log(:info, "DEBUG: #{group_list.inspect}")
  list_values.each { |key, value| $evm.object[key] = value }

  exit MIQ_OK
end
