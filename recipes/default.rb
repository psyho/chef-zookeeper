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

include_recipe 'emerge'

p = "/etc/portage/package.license"
java_package = "dev-java/sun-jdk"

update_file "enable java" do
  action :append
  path p
  body "#{java_package} dlj-1.1"
  not_if "grep '#{java_package}' #{p}"
end

package java_package do
  action :install
end

app_root_dir = node[:zookeeper_root_dir]
data_dir = node[:zookeeper_data_dir]
config_dir = node[:zookeeper_config_dir]
client_port = node[:zookeeper_client_port]
myid = node[:zookeeper_myid]
servers = node[:zookeeper_server_list]

user "zookeeper" do
  #system true
  shell "/bin/false"
end

[app_root_dir, config_dir, data_dir].each do |dir|
  directory dir do
    owner "zookeeper"
    group "zookeeper"
    mode "0755"
    action :create
  end
end

remote_file "/tmp/zookeeper.tar.gz" do
  owner "root"
  source "zookeeper-#{node[:zookeeper_version]}.tar.gz"
end

bash "untar zookeeper" do
  user "root"
  cwd "/tmp"
  code %(tar -zxf /tmp/zookeeper.tar.gz)
  not_if { File.exists? "/tmp/zookeeper-#{node[:zookeeper_version]}" }
end

bash "copy zookeeper root" do
  user "root"
  cwd "/tmp"
  code "cp -r /tmp/zookeeper-#{node[:zookeeper_version]}/* #{app_root_dir}"
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

template "/etc/init.d/zookeeper" do
  owner "root"
  mode "0755"
  source "init.erb"
  variables :root_dir => app_root_dir
end

bash "run zookeeper at startup" do
  user "root"
  code "rc-update add zookeeper default"
end

service "zookeeper" do
  action :start
end
