# Chef A2 Terraform

Consists of
* Chef Automate 2 server
* Chef Server
* Route53 DNS records

Currently only installing the packages and doing basic configuration - the rest is left as an exercise to the reader.

## Chef Server Manual Config
* "sudo chef-server-ctl set-secret data_collector token '<API_TOKEN_FROM_STEP_1>'",
* "sudo chef-server-ctl restart nginx",
* "sudo chef-server-ctl restart opscode-erchef",
* Edit /etc/opscode/chef-server.rb
```
data_collector['root_url'] = 'https://automate.example.com/data-collector/v0/'
# Add for chef client run forwarding
data_collector['proxy'] = true
# Add for compliance scanning
profiles['root_url'] = 'https://automate.example.com'
```
* # Save and close the file
* sudo chef-server-ctl reconfigure
* sudo chef-server-ctl user-create -p admin Admin User admin@example.com
* sudo chef-server-ctl org-create test TestOrg
* sudo chef-server-ctl org-user-add test admin
* sudo chef-server-ctl grant-server-admin-permissions admin

