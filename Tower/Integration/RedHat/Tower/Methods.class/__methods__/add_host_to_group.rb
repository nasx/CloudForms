=begin
  add_host_to_group.rb
  Author: Chris Keller <ckeller@redhat.com>
  Description: Manually add a host to an inventory group
=end

require 'rest-client'
require 'openssl'
require 'json'

prov = $evm.root['miq_provision']

ip_addr = prov.get_option(:ip_addr)
vm_name = prov.get_option(:vm_name)

inventory_id = prov.get_option(:dialog_param_tower_inventory_id)
group_id = prov.get_option(:dialog_param_root_group_id)

password = $evm.object.decrypt('password')
username = $evm.object['username']
hostname = $evm.object['hostname']

url = "https://#{hostname}/api/v1/groups/#{group_id}/hosts/"
hash = {:variables=>"ansible_ssh_host: #{ip_addr}", :name=>"#{vm_name}", :enabled=>true, :inventory=>"#{inventory_id}"}

$evm.log(:info, "DEBUG: username = #{username}, hostname = #{hostname}, url = #{url}, ip_addr = #{ip_addr}, hostname = #{vm_name}, inventory_id = #{inventory_id}, group_id = #{group_id}")
$evm.log(:info, "DEBUG: hash: #{hash.to_json}")

response = RestClient::Request.new(
	:url => url,
	:method => :post,
	:user => username,
	:password => password,
	:headers => { :accept => "application/json", :content_type => "application/json" },
	:payload => hash.to_json,
	:verify_ssl => OpenSSL::SSL::VERIFY_NONE
).execute

$evm.log(:info, response.to_str)
 
exit MIQ_OK
