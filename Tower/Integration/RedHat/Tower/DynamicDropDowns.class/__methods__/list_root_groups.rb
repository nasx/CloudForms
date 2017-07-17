=begin
  list_root_groups.rb
  Author: Chris Keller <ckeller@redhat.com>
  Description: This method will list root groups from a Tower inventory
  (requires element updated with param_tower_inventory_id) 
=end

require 'rest-client'
require 'openssl'
require 'json'

inventory_id = $evm.root['dialog_param_tower_inventory_id']

password = $evm.object.decrypt('password')
username = $evm.object['username']
hostname = $evm.object['hostname']

url = "https://#{hostname}/api/v1/inventories/#{inventory_id}/root_groups"

$evm.log(:info, "DEBUG: username = #{username}, hostname = #{hostname}, url = #{url}, inventory_id = #{inventory_id}")

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
group_list = {}

hash['results'].each do |i|
  $evm.log(:info, "DEBUG: group_list[#{i['id']}] = #{i['name']}")
  group_list[i['id']] = i['name']
end

list_values = {
  'sort_by' => :value,
  'required' => false,
  'default_value' => false,
  'values' => group_list
}

list_values.each { |key, value| $evm.object[key] = value }

exit MIQ_OK
