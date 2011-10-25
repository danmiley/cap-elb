require "cap-elb/version"
require 'right_aws'

unless Capistrano::Configuration.respond_to?(:instance)
  abort "capistrano/elb requires Capistrano 2"
end

module Capistrano
  class Configuration
    module LoadBalancers
      # Associate a group of EC2 instances behind a load balancer with a role. In order to use this, you
      # must use the Load Balancer feature in Amazon EC2 to group your servers
      # by role.
      # 
      # First, specify the load balancer name, then the roles and params:
      #
      #   group :webserver, :web
      #   group :app_myappname, :app
      #   group "MySQL Servers", :db, :port => 22000
      def loadbalancer (which, *args)

	      # list of all the instances assoc'ed with this account
	      @ec2_api ||= RightAws::Ec2.new(fetch(:aws_access_key_id), fetch(:aws_secret_access_key), fetch(:aws_params, {}))

	      # fetch a raw list all the load balancers
	      @elb_api ||= RightAws::ElbInterface.new(fetch(:aws_access_key_id), fetch(:aws_secret_access_key))
	      # only get the named load balancer
	      named_elb_instance = @elb_api.describe_load_balancers.delete_if{ |i| i[:load_balancer_name] != which.to_s }

	      print "named elb instnaces" + named_elb_instance.to_s

	      elb_ec2_instances = named_elb_instance[0][:instances] rescue {}

#	      print "named elb ec2 instnaces" + elb_ec2_instances.to_s
	      print "here are our ARGSXXX" + args[1].to_s

	      # this is the target state we extract from param, unless that param is present in the instance, we dont update
	      run_state = args[1][:state] rescue 'run' 

	      #now, we have a hash of either zero or one ELBs, assuming unique names
	      @ec2_api.describe_instances.delete_if{ |i| i[:aws_state] != "running"}.each do |instance|
		      # unless this ec2 instance is in the LB, nuke it
		      if elb_ec2_instances.include?(instance[:aws_instance_id]) && instance[:tags]['state'] == run_state
			      server(instance[:dns_name], *args)
		      end
	      end
      end
    end
    
    include LoadBalancers
  end
end

# module Cap
#   module Elb
#     # Your code goes here...
#   end
# end
