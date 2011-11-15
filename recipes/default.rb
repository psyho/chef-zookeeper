#
# Cookbook Name:: zookeeper-ubuntu
# Recipe:: default
#
# Copyright 2011, Francesco Salbaroli
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
include_recipe "apt"

# install pre-requisites
package "default-jre"

# install zookeeper
package "zookeeper"
package "zookeeperd"


servers = search(:node, "role:#{node[:environment]} and role:zookeeper").select{|s| node[:application][:name] == s[:application][:name] }

# set myid if not already set
if node['zookeeper']['myid'].nil?
  myid = 1
  servers.each do |s|
    if s.name != node.name && s['zookeeper']['myid'] && myid <= s['zookeeper']['myid'].to_i
      myid = s['zookeeper']['myid'].to_i + 1
    end
  end
  node['zookeeper']['myid'] = myid
  # set myid of this node in the server list -- used to create zoo.cfg
  servers.each{|s| s['zookeeper']['myid'] = myid if s.name == node.name}
end

data_dir = node['zookeeper']['data_dir']
config_dir = node['zookeeper']['config_dir']
client_port = node['zookeeper']['client_port']
myid = node['zookeeper']['myid']

directory config_dir do
   owner "root"
   group "root"
   mode "0755"
   action :create
end

template_variables = {
   :zookeeper_servers           => servers,
   :zookeeper_data_dir          => data_dir,
   :zookeeper_client_port       => client_port
}

%w{ configuration.xsl  environment  log4j.properties zoo.cfg }.each do |templ|
   template "#{config_dir}/#{templ}" do
      source "#{templ}.erb"
      mode "0644"
      owner "root"
      group "root"
      variables(template_variables)
   end
end

directory data_dir do
   owner "zookeeper"
   group "zookeeper"
   mode "0755"
   action :create
end

template "#{config_dir}/myid" do
   source "myid.erb"
   mode "0644"
   owner "zookeeper"
   group "zookeeper"
   variables({:myid => myid})
end

service "zookeeper" do
#   provider Chef::Provider::Service::Upstart
   action :restart
   running true
   supports :status => true, :restart => true
end 
