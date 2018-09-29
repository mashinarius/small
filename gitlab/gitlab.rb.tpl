gitlab_rails['ldap_enabled'] = true
gitlab_rails['ldap_servers'] = YAML.load_file('/etc/gitlab/ldap.yml')
external_url 'https://${GL_FQDN}'
letsencrypt['enable'] = true
letsencrypt['contact_emails'] = ['${GL_EMAIL}']
