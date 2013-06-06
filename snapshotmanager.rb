#!/usr/bin/env ruby
#
#  Author: Kristopher Zenter
#  Date: 5/23/2012
#  Description: Backs up volumes
#
require 'aws-sdk'
require 'date'
require 'net/http'
# Specify the access key and secret access ID
ACCESS_KEY = 'YOUR ACCESS KEY'
SECRET_KEY = 'YOUR SECRET KEY'
days_to_keep = 14
now = Date.today
prune_date = (now - days_to_keep).to_time
hostname = `hostname -s`.chomp!
# get instance_id
url = URI.parse("http://169.254.169.254/latest/meta-data/instance-id")
response = Net::HTTP.start(url.host, url.port) do |http|
  http.get(url.request_uri)
end
instance_id = response.body

AWS.config(:access_key_id => ACCESS_KEY, :secret_access_key => SECRET_KEY)

ec2 = AWS::EC2.new

#
# Delete logic
#
snapshots = ec2.snapshots.filter('tag:host', "#{hostname}")
snapshots.each do |snapshot|
   if snapshot.start_time < prune_date
      puts "deleting: snapshot.id"
      snapshot.delete
   end
end

#
# Create Volumes!
#
volumes = ec2.volumes
volumes.each do |volume|
   #puts volume.id + " " 
   volume.attachments.each do |v|
      if v.instance.id == instance_id
         ubuntudev = v.device
         ubuntudev["/dev/s"] = "/dev/xv"
         mount=`mount|grep #{ubuntudev}|awk '{ print $3 }'`.chomp
         puts "Creating snapshot for #{volume.id} #{mount}"
         snapshot = volume.create_snapshot("#{hostname}:#{mount} backup-#{now}")
         sleep 10 until [:completed, :error].include?(snapshot.status)
         puts "Snapshot: snapshot.status"
         puts "Adding tags"
         ec2.snapshots[snapshot.id].tags["host"] = "#{hostname}"
         ec2.snapshots[snapshot.id].tags["mount"] = "#{v.device}"
         ec2.snapshots[snapshot.id].tags["mountpoint"] = "#{mount}"
      end
   end
end
puts "Complete!"
