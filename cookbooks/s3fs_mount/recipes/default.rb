#
# Cookbook Name:: s3fs_mount
# Recipe:: default
#

http_request "reporting for s3fs" do
  url node[:reporting_url]
  message :message => "configuring s3fs"
  action :post
  epic_fail true
end

execute "modprobe-fuse" do
  command "modprobe fuse"
end

execute "setup-/etc/passwd-s3fs" do
  command "echo '#{node[:aws_secret_id]}:#{node[:aws_secret_key]}' > /etc/passwd-s3fs"
  not_if { File.exist?('/etc/passwd-s3fs') }
end

directory "/mnt/s3cache" do
  owner node[:owner_name]
  group node[:owner_name]
  mode 0775
end

log_bucket = "#{node[:environment][:name]}-shared-logs-#{Digest::SHA1.hexdigest(node[:aws_secret_id])[0..6]}"
config_bucket = "#{node[:environment][:name]}-shared-config-#{Digest::SHA1.hexdigest(node[:aws_secret_id])[0..6]}"

ruby_block "make-s3-bucket" do
  block do
    require 'digest'
    require 'aws/s3'
    AWS::S3::Base.establish_connection!(
                                        :access_key_id     => node[:aws_secret_id],
                                        :secret_access_key => node[:aws_secret_key]
                                        )
    [log_bucket, config_bucket].each do |bucket|
      begin
        AWS::S3::Bucket.create bucket
      rescue AWS::S3::ResponseError
      end
    end
  end
end

#bash "add-logs-to-fstab" do
  #code "rmdir /data/choruscard/shared/log"
  #code "echo 's3fs##{log_bucket} /data/choruscard/shared/log fuse allow_other,accessKeyId=#{node[:aws_secret_id]},secretAccessKey=#{node[:aws_secret_key]},use_cache=/mnt/s3cache 0 0' >> /etc/fstab"
  #not_if "grep 's3fs##{log_bucket}' /etc/fstab"
#end

bash "add-config-to-fstab" do
  #code "rmdir /data/choruscard/shared/config"
  code "echo 's3fs##{config_bucket} /data/choruscard/shared/config fuse allow_other,accessKeyId=#{node[:aws_secret_id]},secretAccessKey=#{node[:aws_secret_key]},use_cache=/mnt/s3cache 0 0' >> /etc/fstab"
  not_if "grep 's3fs##{config_bucket}' /etc/fstab"
end

bash "maybe-start-s3fs" do
  #code "/usr/bin/s3fs #{log_bucket} /data/choruscard/shared/log -ouse_cache=/mnt/s3cache -oallow_other"
  code "/usr/bin/s3fs #{config_bucket} /data/choruscard/shared/config -ouse_cache=/mnt/s3cache -oallow_other"
  not_if "ps -A | grep s3fs"
end
