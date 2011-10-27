require 'right_aws'
require "cap-elb/version"

unless Capistrano::Configuration.respond_to?(:instance)
  abort "cap-elb requires Capistrano 2"
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
      def loadbalancer (named_load_balancer, *args)
	      require_arglist = args[1][:require] rescue {}
	      exclude_arglist = args[1][:exclude] rescue {}

	      # list of all the instances assoc'ed with this account
	      @ec2_api ||= RightAws::Ec2.new(fetch(:aws_access_key_id), fetch(:aws_secret_access_key), fetch(:aws_params, {}))

	      # fetch a raw list all the load balancers
	      @elb_api ||= RightAws::ElbInterface.new(fetch(:aws_access_key_id), fetch(:aws_secret_access_key))

	      # only get the named load balancer
	      named_elb_instance = @elb_api.describe_load_balancers.delete_if{ |instance| instance[:load_balancer_name] != named_load_balancer.to_s }

	      # must exit if no load balancer on record for this account by given name in cap config file
	      raise Exception, "No load balancer named: #{named_load_balancer.to_s} for aws account with this access key: #{:aws_access_key_id}" if named_elb_instance.empty?

	      elb_ec2_instances = named_elb_instance[0][:instances] rescue {}

	      # get the full instance list for account, this is necessary to subsquently fish out the :dns_name for the instances that survive our reduction steps
	      account_instance_list = @ec2_api.describe_instances

	      # reduce to only the instances in the named ELB
	      account_instance_list.delete_if { |i| ! elb_ec2_instances.include?(i[:aws_instance_id]) }

	      # reduce against 'require' args, if an instance doesnt have the args in require_arglist, remove
	      account_instance_list.delete_if { |i| ! all_args_within_instance(i, require_arglist) }  unless require_arglist.nil? or require_arglist.empty?

	      # reduce against 'exclude_arglist', if an instance has any of the args in exclude_arglist, remove
	      account_instance_list.delete_if { |i|   any_args_within_instance(i, exclude_arglist) }  unless exclude_arglist.nil? or exclude_arglist.empty?

	      # finally load the derived instances into the serverlist used by capistrano tasks
	      account_instance_list.each do |instance|
		      server(instance[:dns_name], *args)
	      end
      end

      private

      def any_args_within_instance(instance, exclude_arglist)
	      exargs = exclude_arglist.clone # must copy since delete transcends scope; if we don't copy, subsequent 'map'ped enum arglists would be side-effected
	      tag_exclude_state = nil # default assumption
	      # pop off a :tags arg to treat separately, its a separate namespace
	      tag_exclude_arglist = exargs.delete(:tags)

	      tag_exclude_state = tag_exclude_arglist.map { |k, v| (instance[:tags][k] == v rescue nil) }.inject(nil) { |inj, el| el || inj } if !tag_exclude_arglist.nil?
	      # we want all nils for the result here, so we logical-or the result map, and invert it
	      tag_exclude_state || exargs.map { |k, v| instance[k] == v }.inject(nil) { |inj, el| inj || el }
      end

      # the instance has attributes
      def all_args_within_instance(instance, require_arglist)
	      reqargs = require_arglist.clone # must copy since delete transcends scope; if we don't copy, subsequent 'map'ped enum arglists would be side-effected
	      tag_require_state = true # default assumption
	      # pop off a :tags arg to treat separately, effectively  a separate namespace to be checked agains
	      tag_require_arglist = reqargs.delete(:tags)
	      tag_require_state = tag_require_arglist.map { |k, v| (instance[:tags][k] == v rescue nil) }.inject(nil) { |inj, el| el || inj } if !tag_require_arglist.nil?

	      # require arglist is a hash with k/v's, each of those need to be in the instance
	      tag_require_state && reqargs.map { |k, v| instance[k] == v }.inject(true) { |inj, el| inj && el }
      end

    end
    
    include LoadBalancers
  end
end

# stub for future extensions
 module Cap
   module Elb
   end
 end
