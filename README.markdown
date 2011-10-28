cap-elb
=================================================

Capistrano plugin or deploying to Amazon EC2 instances behind Amazon ELBs (Elastic Load Balancers)

Introduction
============

This capistrano plugin lets you perform capistrano deployment tasks on  either complete or highly segmented AWS instance sets within an AWS load balancer under your control.

Installation
============

`cap-elb` is a Capistrano plug-in configured as Ruby gem.  You can install from rubygems.com or build from source via GitHub fork or downlaod.

RubyGems install:
---------
	$ gem install cap-elb

How to Use
=====

In order to use the `cap-elb` plugin, you must require it in your `deploy.rb`:

	require 'cap-elb'

If you have already been doing capistrano deploys to your AWS instances, you probably already have your
AWD credentials configured.  Either add your credentials to your ~/.caprc :

	set :aws_access_key_id, 'YOUR_AWS_ACCESS_KEY_ID'
	set :aws_secret_access_key, 'YOUR_AWS_SECRET_ACCESS_KEY'

or, directly in your deploy file:

	set :aws_access_key_id, 'YOUR_AWS_ACCESS_KEY_ID'
	set :aws_secret_access_key, 'YOUR_AWS_SECRET_ACCESS_KEY'

If you wish, you can also set other AWS specfic parameters:

	set :aws_params, :region => 'us-east-1'
	
In order to define your instance groups, you must specify the security group name, the roles and params:
Next you will set up your instance sets associated with a named load balancer instance in your AWS account.
You will call out the load balancer name (e.g. 'lb_webserver'), the capistrano role associated with that load balancer (.e.g. 'web'),
and any optional params.

	loadbalancer :lb_webserver, :web
	loadbalancer :lb_appserver, :app
	loadbalancer :lb_dbserver, :db, :port => 22000

There are two special parameters you can add, :require and :exclude.

AWS instances have top level metadata and user defined tag data, and this data can be used by your loadbalancer rule
 to include or exclude certain instances from the instance set.

Take the :require keyword; Lets say  we only want to deploy to AWS instances which are in the 'running' state. To do that:

	loadbalancer :lb_appserver, :app, :require => { :aws_state => "running" }

The server set defined here for role :app are all instances in the loadbalancer 'lb_appserver' with aws_state set to 'running'.

Perhaps you have added tags to your instances, if so, you might want to deploy to only the instances meeting a specific tag value:

	loadbalancer :lb_appserver, :app, :require => { :aws_state => "running", :tags => {'fleet_color' => "green", 'tier' => 'free'} }

The server set defined here for role :app are all instances in the loadbalancer 'lb_appserver' with aws_state set to 'running',
and that have the named 2 tags set, with exactly those values for each.  There can be other tags in the instance, but the named tags in the rule must be present
for the given instance to make it into the server set.

Now consider the :exclude keyword; Lets say we do not want to deploy to AWS instances which are 'micro' sized. To do that:
	
	loadbalancer :lb_appserver, :app, :exclude => { :aws_instance_type => "t1.micro"  }

You can exclude instances that have certain tags:

	loadbalancer :lb_appserver, :app, :exclude => { :aws_instance_type => "t1.micro", :tags => {'state' => 'dontdeploy' }  }

When your capistrono script is complete, you can deploy to all instances within the ELB that meet your criteria with:

	% cap deploy

Here's an example of a task that does a quick list of the instance ids (if any) within the load balancer associated with the 'app' role
that meets the criteria you laid out in the loadbalancer definition line, 
add this to your cap deploy file:

	# run with cap ec2:list
	namespace :ec2 do
		desc "list instances"
		task :list, :roles => :app do
			run "hostname"
		end
	end

This will give you the list of hosts behind the load balancer that meet the criteria.
	% cap ec2:list

Documentation
=============
Additional Ruby class/method documentation is available at: [http://rubydoc.info/gems/cap-elb/frames] (http://rubydoc.info/gems/cap-elb/frames)

* capistrano: [http://capify.org](http://capify.org)
* Amazon AWS: [http://aws.amazon.com](http://aws.amazon.com)
* Amazon AMI instance metadata: [http://docs.amazonwebservices.com/AWSEC2/latest/UserGuide/index.html?AESDG-chapter-instancedata.html](http://docs.amazonwebservices.com/AWSEC2/latest/UserGuide/index.html?AESDG-chapter-instancedata.html)
* Amazon AMI Tags: [http://docs.amazonwebservices.com/AWSEC2/latest/UserGuide/Using_Tags.html[(http://docs.amazonwebservices.com/AWSEC2/latest/UserGuide/Using_Tags.html)

Credits
=======
* capistrano: [Jamis Buck](http://github.com/jamis/capistrano)
* capistrano-ec2group: [Logan Raarup](http://github.com/logandk) - Logan's 2009 work with cap deploy using security group abstraction got me going on how to do an AWS oriented cap plug-in, thank you!



Copyright (c) 2011 Dan Miley, released under the MIT license