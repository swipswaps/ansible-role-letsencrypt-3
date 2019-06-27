Letsencrypt
================

Configure self-signed certificates and generate scripts to migrate to LetsEncrypt certificates on Apache. The webserver
will need to be configured to use the certs, chains, and keys in `/etc/letsencrypt/live/<ServerName>/{chain,privkey,cert}.pem`

When you're ready to switch over to LetsEncrypt, just run the migration script for the vhost. It is built to handle
failure, and will backup the certs and restore them if anything goes wrong.

Role Variables
--------------

| Variables | Description | Default |
|-|-|-|
|`apache_vhosts_ssl`|List of vhosts. This should already be defined if you're using the geerylingguy.apache role. If you're not, then look at the example playbook. This role only needs to have the `servername` and `documentroot` variables set.|`None`|
|`le_admin_mailto`|Email address for LetsEncrypt to send notices about protocol changes and expiry notices|`sysops@tag1consulting.com`| 
|`le_migrate_script_basepath`|Directory to store the migration scripts|`/root/`|
|`le_migrate_script_prefix`|Prefix to script filename|`migrate`|
|`le_selfsign_base_dir`|Directory to store all files related to self-signing certificates|`/etc/ssl/`|
|`le_selfsign_key_name`|Name of file in `le_selfsign_base_dir` to do all signing with|`root-key.pem`|
|`le_selfsign_chain_name`|Name of chain file in `le_selfsign_base_dir`. It contains no private information|`fake-chain.pem`|

Dependencies
------------

- Geerlingguy.Apache

Example Playbook
----------------

Run the role with the `never` tag enabled in testing, run it normally in production. The `never` tag will setup a local
ACME server with nearly unlimited rates and the cutover scripts will use that instead of LetsEncrypt's servers.

In `host_vars/test.com`:

```YAML
apache_vhosts:
  - servername: "test.com"
    serveralias: "localhost"
    documentroot: "/var/www/html"
    extra_parameters: |
      <Proxy "fcgi://localhost:9000/">
        ProxySet timeout=300
      </Proxy>
      <FilesMatch "\.php$">
        SetHandler proxy:fcgi://localhost:9000/
      </FilesMatch>

apache_vhosts_ssl:
  - servername: "test.com"
    serveralias: "localhost"
    certificate_file: /etc/letsencrypt/live/test.com/cert.pem
    certificate_chain_file: /etc/letsencrypt/live/test.com/chain.pem
    certificate_key_file: /etc/letsencrypt/live/test.com/privkey.pem
    documentroot: "/var/www/html"
    extra_parameters: |
      <Proxy "fcgi://localhost:9000/">
        ProxySet timeout=300
      </Proxy>
      <FilesMatch "\.php$">
        SetHandler proxy:fcgi://localhost:9000/
      </FilesMatch>
```

In a tasks file:

```YAML
- name: Setup letsencrypt
  import_role: 
    name: tag1-letsencrypt
```

**OR**

In a playbook:

```YAML
- hosts: webservers
  roles:
     - { role: tag1-letsencrypt }
```

License
-------

BSD

Author
------

Tag1 Consulting
