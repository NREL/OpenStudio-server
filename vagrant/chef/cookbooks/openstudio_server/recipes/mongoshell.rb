#
# Cookbook Name:: openstudio_server
# Recipe:: mongoshell
#

# Install the mongo-shell only
include_recipe 'mongodb::mongodb_org_repo'
package 'mongodb-org-shell'
