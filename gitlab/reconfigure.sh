!/bin/bash
DOMAIN_NAME="mashinarius.com"
IPA_FQDN_C=$( dig +short @consul01.mashinarius.com  freeipa.service.consul. | grep $DOMAIN_NAME )
IPA_FQDN_C=$(echo $IPA_FQDN_C | sed 's/.$//' )
echo $IPA_FQDN_C

sed -i -- 's/${IPA_FQDN}/'$IPA_FQDN_C'/g' ldap.yml

#cp /opt/consul/scripts/ldap.yml /opt/gitlab/config/ldap.yml
#echo "gitlab_rails['ldap_enabled'] = true" >> /opt/gitlab/config/gitlab.rb
#echo "gitlab_rails['ldap_servers'] = YAML.load_file('/etc/gitlab/ldap.yml')" >> /opt/gitlab/config/gitlab.rb

docker exec -it gitlab sh -c 'gitlab-ctl reconfigure'