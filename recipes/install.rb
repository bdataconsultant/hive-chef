include_recipe "java"

my_ip = my_private_ip()

group node['hive2']['group'] do
  action :create
  not_if "getent group #{node['hive2']['group']}"
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

user node['hive2']['user'] do
  home "/home/#{node['hive2']['user']}"
  action :create
  shell "/bin/bash"
  manage_home true
  system true
  not_if "getent passwd #{node['hive2']['user']}"
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

group node['hive2']['group'] do
  action :modify
  members node['hive2']['user']
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

group node['hive2']['group'] do
  action :modify
  members node['hadoop']['user']
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

group node['hive2']['group'] do
  action :modify
  members node['airflow']['user']
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

group node['hive2']['group'] do
  action :modify
  members node['sqoop']['user']
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

group node['kagent']['certs_group'] do
  action :create
  not_if "getent group #{node['kagent']['certs_group']}"
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

group node['kagent']['certs_group'] do
  action :modify
  members node['hive2']['user']
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

package_url = "#{node['hive2']['url']}"
base_package_filename = File.basename(package_url)
cached_package_filename = "/tmp/#{base_package_filename}"

remote_file cached_package_filename do
  source package_url
  owner "#{node['hive2']['user']}"
  mode "0644"
  action :create_if_missing
end

# Extract Hive
hive_downloaded = "#{node['hive2']['home']}/.hive_extracted_#{node['hive2']['version']}"

bash 'extract-hive' do
        user "root"
        group node['hive2']['group']
        code <<-EOH
                set -e
                tar zxf #{cached_package_filename} -C /tmp
                mv /tmp/apache-hive-#{node['hive2']['version']}-bin #{node['hive2']['dir']}
                # remove old symbolic link, if any
                rm -f #{node['hive2']['base_dir']}
                ln -s #{node['hive2']['home']} #{node['hive2']['base_dir']}
                chown -R #{node['hive2']['user']}:#{node['hive2']['group']} #{node['hive2']['home']}
                chmod 770 #{node['hive2']['home']}
                chown -R #{node['hive2']['user']}:#{node['hive2']['group']} #{node['hive2']['base_dir']}
                touch #{hive_downloaded}
                chown -R #{node['hive2']['user']}:#{node['hive2']['group']} #{hive_downloaded}
        EOH
     not_if { ::File.exists?( "#{hive_downloaded}" ) }
end

# Install the mysql-jdbc connector
remote_file "#{node['hive2']['lib_dir']}/mysql-connector-java-#{node['hive2']['mysql_connector_version']}-bin.jar" do
  source node['hive2']['mysql_connector_url']
  checksum node['hive2']['mysql_connector_checksum']
  owner node['hive2']['user']
  group node['hive2']['group']
  mode '0755'
  action :create_if_missing
end

# Install the hudi-hadoop-mr-bundle
remote_file "#{node['hive2']['base_dir']}/lib/hudi-hadoop-mr-bundle-#{node['hive2']['hudi_version']}.jar" do
  source node['hive2']['hudi_hadoop_mr_bundle_url']
  owner node['hive2']['user']
  group node['hive2']['group']
  mode '0644'
  action :create_if_missing
end

# Install the prometheus JMX exporter
base_package_filename = File.basename(node['hive2']['jmx']['prometheus_exporter']['url'])
remote_file "#{node['hive2']['lib_dir']}/#{base_package_filename}" do
  source node['hive2']['jmx']['prometheus_exporter']['url']
  owner node['hive2']['user']
  group node['hive2']['group']
  mode '0755'
  action :create
end
