require 'right_aws'
require 'cap-elb/version'

unless Capistrano::Configuration.respond_to?(:instance)
  abort "cap-elb requires Capistrano 2"
end

module Capistrano
  class Configuration
    module LoadBalancers
	    # Associate a group of EC2 instances behind a load balancer with a role to be used for Capistrano tasks. In order to use this, you
	    # must use the Load Balancer feature in Amazon EC2 to group your servers
	    # by role.
	    # 
	    # In order to use the loadbalancer extension in your capistrano scripts.
	    # you will need to install the `cap-elb` plugin, then krequire it in your `deploy.rb`:

	    # 	require 'cap-elb'

	    # If you have already been doing capistrano deploys to your AWS instances, you probably already have your
	    # AWD credentials configured.  Either add your credentials to your ~/.caprc :

	    # 	set :aws_access_key_id, 'YOUR_AWS_ACCESS_KEY_ID'
	    # 	set :aws_secret_access_key, 'YOUR_AWS_SECRET_ACCESS_KEY'

	    # or, directly in your deploy file:

	    # 	set :aws_access_key_id, 'YOUR_AWS_ACCESS_KEY_ID'
	    # 	set :aws_secret_access_key, 'YOUR_AWS_SECRET_ACCESS_KEY'

	    # If you wish, you can also set other AWS specfic parameters:

	    # 	set :aws_params, :region => 'us-east-1'
	    
	    # In order to define your instance groups, you must specify the security group name, the roles and params.
	    # Next you will set up your instance sets associated with a named load balancer instance in your AWS account.
	    # You will call out the load balancer name (e.g. 'lb_webserver'), the capistrano role associated with that load balancer (.e.g. 'web'),
	    # and any optional params.

	    # 	loadbalancer :lb_webserver, :web
	    # 	loadbalancer :lb_appserver, :app
	    # 	loadbalancer :lb_dbserver, :db, :port => 22000

	    # There are two special parameters you can add, :require and :exclude.

	    # AWS instances have top level metadata and user defined tag data, and this data can be used by your loadbalancer rule
	    #  to include or exclude certain instances from the instance set.

	    # Take the :require keyword; Lets say  we only want to deploy to AWS instances which are in the 'running' state. To do that:

	    # 	loadbalancer :lb_appserver, :app, :require => { :aws_state => "running" }

	    # The server set defined here for role :app are all instances in the loadbalancer 'lb_appserver' with aws_state set to 'running'.

	    # Perhaps you have added tags to your instances, if so, you might want to deploy to only the instances meeting a specific tag value:

	    # 	loadbalancer :lb_appserver, :app, :require => { :aws_state => "running", :tags => {'fleet_color' => "green", 'tier' => 'free'} }

	    # The server set defined here for role :app are all instances in the loadbalancer 'lb_appserver' with aws_state set to 'running',
	    # and that have the named 2 tags set, with exactly those values for each.  There can be other tags in the instance, but the named tags in the rule must be present
	    # for the given instance to make it into the server set.

	    # Now consider the :exclude keyword; Lets say we do not want to deploy to AWS instances which are 'micro' sized. To do that:
	    
	    # 	loadbalancer :lb_appserver, :app, :exclude => { :aws_instance_type => "t1.micro"  }

	    # You can exclude instances that have certain tags:

	    # 	loadbalancer :lb_appserver, :app, :exclude => { :aws_instance_type => "t1.micro", :tags => {'state' => 'dontdeploy' }  }

	    # When your capistrono script is complete, you can deploy to all instances within the ELB that meet your criteria with:

	    # 	% cap deploy

	    # Here's an example of a task that does a quick list of the instance ids (if any) within the load balancer associated with the 'app' role
	    # that meets the criteria you laid out in the loadbalancer definition line, 
	    # add this to your cap deploy file:

	    # 	# run with cap ec2:list
	    # 	namespace :ec2 do
	    # 		desc "list instances"
	    # 		task :list, :roles => :app do
	    # 			run "hostname"
	    # 		end
	    # 	end

	    # This will give you the list of hosts behind the load balancer that meet the criteria.
	    # 	% cap ec2:list

      def loadbalancer (named_load_balancer, *args)

	      require_arglist = args[1][:require] rescue {}
	      exclude_arglist = args[1][:exclude] rescue {}
	      named_region = fetch(:aws_params)[:region] rescue 'us-east-1'

	      # can't have a EC2_URL env var if region has been provided
	      # otherwise the RightScale gem will overresolve the url and region and form a bad endpoint
	      # in the RightAWS::Ec2.new class
	      # this undefine only lasts the extent of the cap task, doesn't affect the parent process.
	      ENV['EC2_URL'] = nil if !named_region.nil?

	      # list of all the instances assoc'ed with this account
	      @ec2_api ||= RightAws::Ec2.new(fetch(:aws_access_key_id), fetch(:aws_secret_access_key), fetch(:aws_params, {}))

	      # fetch a raw list all the load balancers
	      @elb_api ||= RightAws::ElbInterface.new(fetch(:aws_access_key_id), fetch(:aws_secret_access_key), :region => named_region)
	      
	      # only get the named load balancer
	      named_elb = @elb_api.describe_load_balancers.delete_if{ |instance| instance[:load_balancer_name] != named_load_balancer.to_s }

	      # must exit if no load balancer on record for this account by given name in cap config file
	      raise Exception, "No load balancer found named: #{named_load_balancer.to_s} for aws account with this access key: #{fetch(:aws_access_key_id)} in this region: #{named_region}" if named_elb.nil?
	      # probe for the load balancer ec2 instance set, if this raises Exception, load balancer can't be found
	      named_elb[0] rescue raise Exception, "No load balancer found named: #{named_load_balancer.to_s} for aws account with this access key: #{fetch(:aws_access_key_id)} in this region: #{named_region}" 
	      raise Exception, "No instances within this load balancer: #{named_load_balancer.to_s} for aws account with this access key: #{fetch(:aws_access_key_id)} in this region: #{named_region}" if  named_elb[0][:instances].count == 0

	      elb_ec2_instances = named_elb[0][:instances] rescue {}

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
		      hostname = instance[:dns_name] 
		      hostname = instance[:ip_address] if hostname.empty?   # if host in a VPC, there will be no DNS name, use ip_address instead
		      server(hostname, *args)
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
 # module Cap
 #   module Elb
 #   end
 # end
