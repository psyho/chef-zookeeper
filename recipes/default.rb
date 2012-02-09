#
# Cookbook Name:: zookeeper
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
include_recipe "java"

package "unzip" do
  action :install
end


if node['zookeeper']['environment']['name'].nil? || node['zookeeper']['environment']['name'].empty? then
   log "Environment variable NOT SET, defaulting to current node environment" 
   zookeeper_chef_environment = node.chef_environment
else
   zookeeper_chef_environment = node['zookeeper']['environment']['name']
end

puts "Environment: #{zookeeper_chef_environment}"

if zookeeper_chef_environment == "_default" then
   raise "Can't run on default environment"
end

if Chef::Config.solo then
   node_list = [node]
else
   node_list = search(:node, "chef_environment:#{zookeeper_chef_environment}")
end

if node_list.empty? then
   raise "No nodes matching the search pattern!"
end

app_root_dir = node['zookeeper']['root_dir']
data_dir = node['zookeeper']['data_dir']
config_dir = node['zookeeper']['config_dir']
client_port = node['zookeeper']['client_port']
myid = node['zookeeper']['myid']
servers = node['zookeeper']['server_list']

directory app_root_dir do
   owner "zookeeper"
   group "zookeeper"
   mode "0755"
   action :create
end

directory config_dir do
   owner "zookeeper"
   group "zookeeper"
   mode "0755"
   action :create
end

directory data_dir do
   owner "zookeeper"
   group "zookeeper"
   mode "0755"
   action :create
end

bash "retrieve current zookeeper tarball" do
  user "root"
  cwd "/tmp"
  code %(s3cmd get --force s3://#{node.deploybucket}/deployment/zookeeper/zookeeper-#{node.zookeeper.version}.tgz)
end

bash "untar zookeeper" do
  user "root"
  cwd "/tmp"
  code %(tar -zxf /tmp/zookeeper-#{node.zookeeper.version}.tgz)
  not_if { File.exists? "/tmp/zookeeper-#{node.zookeeper.version}" }
end

bash "copy zookeeper root" do
  user "root"
  cwd "/tmp"
  code %(cp -r /tmp/zookeeper-#{node.zookeeper.version}/* /mnt/local/zookeeper)
end

template_variables = {
   :zookeeper_servers           => servers,
   :zookeeper_data_dir          => data_dir,
   :zookeeper_client_port       => client_port
}

%w{ configuration.xsl log4j.properties zoo.cfg }.each do |templ|
   template "#{config_dir}/#{templ}" do
      source "#{templ}.erb"
      mode "0644"
      owner "root"
      group "root"
      variables(template_variables)
   end
end

template "#{config_dir}/myid" do
   source "myid.erb"
   mode "0644"
   owner "zookeeper"
   group "zookeeper"
   variables({:myid => myid})
end

bash "restart zookeeper" do
  user "root"
  cwd "#{app_root_dir}"
  code %(bin/zkServer.sh restart)
end 
