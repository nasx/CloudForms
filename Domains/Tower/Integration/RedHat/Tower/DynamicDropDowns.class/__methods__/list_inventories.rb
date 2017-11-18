=begin
  list_inventories.rb
  Author: Chris Keller <ckeller@redhat.com>
  Description: This method will list Inventories defined in Ansible Tower
=end

require 'rest-client'
require 'openssl'
require 'json'

password = $evm.object.decrypt('password')
username = $evm.object['username']
hostname = $evm.object['hostname']

url = "https://#{hostname}/api/v1/inventories"

$evm.log(:info, "DEBUG: username = #{username}, hostname = #{hostname}, url = #{url}")

response = RestClient::Request.new(
  :url => url,
  :method => :get,
  :user => username,
  :password => password,
  :headers => { :accept => "application/json", :content_type => "application/json" },
  :verify_ssl => OpenSSL::SSL::VERIFY_NONE
).execute

$evm.log(:info, "DEBUG: REST response code = #{response.code}")

hash = JSON.parse(response.to_str)
inventory_list = {}

hash['results'].each do |i|
  $evm.log(:info, "DEBUG: inventory_list[#{i['id']}] = #{i['name']}")
  inventory_list[i['id']] = i['name']
end

list_values = {
  'sort_by' => :value,
  'required' => false,
  'default_value' => false,
  'values' => inventory_list
}

list_values.each { |key, value| $evm.object[key] = value }

exit MIQ_OK
