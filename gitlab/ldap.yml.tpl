main: 
  label: 'FreeIPA'
  host: '${IPA_FQDN}'
  port: 389
  uid: 'uid'
  method: 'plain'
  bind_dn: 'uid=admin,cn=users,cn=accounts,dc=mashinarius'
  password: '${LDAP_SECRET}'
  base: 'cn=accounts,dc=mashinarius'