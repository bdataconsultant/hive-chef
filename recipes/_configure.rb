#include_recipe "hops::wrap"

my_ip = my_private_ip()
nn_endpoint = private_recipe_ip("hops", "nn") + ":#{node.hops.nn.port}"

zk_ips = private_recipe_ips('kzookeeper', 'default')
zk_endpoints = zk_ips.join(",")

mysql_endpoint = private_recipe_ip("ndb", "mysqld") + ":#{node.ndb.mysql_port}"

hopsworks_endpoint = "http://" + private_recipe_ip("hopsworks", "default") + ":#{node.hopsworks.port}"

metastore_ip = private_recipe_ip("hive2", "metastore")

home = "/user/" + node.hive2.user

magic_shell_environment 'HADOOP_HOME' do
  value "#{node.hops.base_dir}"
end

magic_shell_environment 'HIVE_HOME' do
  value "#{node.hive2.base_dir}"
end

magic_shell_environment 'PATH' do
  value "$PATH:#{node.hops.base_dir}/bin:#{node.hive2.base_dir}/bin"
end

#
# See Cloudera tutorial for installing metastore with MySQL
# https://www.cloudera.com/documentation/enterprise/5-8-x/topics/cdh_ig_hive_metastore_configure.html
#
# and this one:
# http://www.toadworld.com/platforms/oracle/w/wiki/11427.using-mysql-database-as-apache-hive-metastore-database
#

cookbook_file "#{node.hive2.base_dir}/lib/mysql-connector-java-5.1.40-bin.jar" do
  source "mysql-connector-java-5.1.40-bin.jar"
  owner node.hive2.user
  group node.hops.group
  mode "0644"
end

hive_dir="#{home}/"
tmp_dirs   = [ hive_dir, hive_dir + "/warehouse" ]
for d in tmp_dirs
  hops_hdfs_directory d do
    action :create_as_superuser
    owner node.hive2.user
    group node.hive2.group
    mode "1770"
    not_if ". #{node.hops.home}/sbin/set-env.sh && #{node.hops.home}/bin/hdfs dfs -test -d #{d}"
  end
end

file "#{node.hive2.base_dir}/conf/hive-site.xml" do
  action :delete
end

template "#{node.hive2.base_dir}/conf/hive-site.xml" do
  source "hive-site.xml.erb"
  owner node.hive2.user
  group node.hive2.group
  mode 0655
  variables({
              :private_ip => my_ip,
              :hopsworks_endpoint => hopsworks_endpoint,
              :nn_endpoint => nn_endpoint,
              :mysql_endpoint => mysql_endpoint,
              :metastore_ip => metastore_ip,
              :zk_endpoints => zk_endpoints,
              :hive_hdfs_home => hive_dir
            })
end

file "#{node.hive2.base_dir}/conf/hiveserver2-site.xml" do
  action :delete
end

template "#{node.hive2.base_dir}/conf/hiveserver2-site.xml" do
  source "hiveserver2-site.xml.erb"
  owner node.hive2.user
  group node.hive2.group
  mode 0655
end

file "#{node.hive2.base_dir}/conf/hive-env.sh" do
  action :delete
end

template "#{node.hive2.base_dir}/conf/hive-env.sh" do
  source "hive-env.sh.erb"
  owner node.hive2.user
  group node.hive2.group
  mode 0655
end

# Until Tez is fixed we'll use mapreduce. Expand memory limits for mapred yarn containers.
file "#{node.hops.conf_dir}/mapred-site.xml" do
  action :delete
end

template "#{node.hops.conf_dir}/mapred-site.xml" do
  source "mapred-site.xml.erb"
  owner node.hops.hdfs.user
  group node.hops.group
  mode 0655
end

