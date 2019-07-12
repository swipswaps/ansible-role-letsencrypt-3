Letsencrypt
===========

Configure self-signed certificates and generate scripts to migrate to LetsEncrypt certificates on any webserver. The webserver
will need to be configured to use the certs, chains, and keys in `/etc/letsencrypt/live/<ServerName>/{chain,privkey,cert}.pem`

When you're ready to switch over to LetsEncrypt, just run the migration script for the vhost. It is built to handle
failure, and will backup the certs and restore them if anything goes wrong.

Usage
-----

The new LetsEncrypt role sets up self-signed certificate, key, and chain files for each ssl-enabled vhost that is defined in the `le_hosts_ssl` variable. 
Since this role was initially developed while using `geerlingguy.apache`, it is super easy to setup when using that
role. Just set `le_hosts_ssl` to `apache_vhosts_ssl`.

```yaml
le_hosts_ssl: "{{ apache_vhosts_ssl }}"
```

**Or by hand**

```yaml
le_hosts_ssl:
  - servername: mywebsite.mydomain
    documentroot: /var/www/mywebsite.mydomain
``` 

The `documentroot` for each hosts needs to match the path that requests to `/` go to for that particular domain. If this
is wrong, the ACME challenge will fail.  

In the case of the above example, the tag1-letsencrypt role will read the
`le_hosts_ssl` variable to create the following changes on the VM:

- Spin up a mock ACME server (if `le_testing==true`)
- Puts a certificate at `/etc/letsencrypt/live/mywebsite.mydomain/cert.pem`
- Puts a private key at `/etc/letsencrypt/live/mywebsite.mydomain/privkey.pem`
- Puts a bogus chain at `/etc/letsencrypt/live/mywebsite.mydomain/chain.pem` 
- Generates a script at `/root/migrate-mywebsite.mydomain.sh` which will do the following in order:
    - Check if the webserver is currently running properly. If not, exit
    - Backup all certificates to `/root/letsencrypt`
    - Perform a dry-run with LetsEncrypt production servers, or skips the dry run if there is a local ACME testing server
       - Exits script if it fails
    - Perform a real ACME client run (there is a hook that deletes the self-signed certs, which is why the backup is needed)
       - Uses local testing server if it is present
       - Uses LetsEncrypt production servers if there is no local testing server
    - Reloads webserver config
       - Restores `/etc/letsencrypt` from backup if the reload fails then reloads the webserver again


Role Variables
--------------

| Variables | Description | Default |
|-|-|-|
|`le_admin_mailto`|Email address for LetsEncrypt to send notices about protocol changes and expiry notices|`sysops@tag1consulting.com`| 
|`le_certbot_venv`|Path to virtualenv that contains certbot and its dependencies|`/root/.certbot_virtualenv`|
|`le_hosts_ssl`|List of hosts to generate self-signed certs and migration scripts for. This array of hashes only needs to have the `servername` and `documentroot` variables set. See the example playbook for an example.|`None`|
|`le_migrate_script_basepath`|Directory to store the migration scripts|`/root/`|
|`le_migrate_script_prefix`|Prefix to script filename|`migrate`|
|`le_selfsign_base_dir`|Directory to store all files related to self-signing certificates|`/etc/ssl/`|
|`le_selfsign_key_name`|Name of file in `le_selfsign_base_dir` to do all signing with|`root-key.pem`|
|`le_selfsign_chain_name`|Name of chain file in `le_selfsign_base_dir`. It contains no private information|`fake-chain.pem`|
|`le_testing`|Determines whether a acme testing server gets stood up| `false`|
|`le_testing_dir`|Path to clone testing server code|`/tmp/boulder`|
|`le_webserver_unit_name`|Name of systemd unit to reload after acme challenge|`apache2`|

Example Playbook
----------------

Run the role with the `le_testing` variable set to `true` in testing, run it normally in production. The `le_testing` variable will setup a local
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

le_hosts_ssl: "{{ apache_vhosts_ssl }}"
```

In a tasks file:

```YAML
- name: Setup letsencrypt
  import_role: 
    name: 
      # Most webservers fail to start the webserver if there are no certs installed yet.
      - tag1-letsencrypt
      # Now that there are certs and keys, the webserver can be brought up
      - some_webserver_role
```

**OR**

In a playbook:

```YAML
- hosts: webservers
  roles:
     - tag1-letsencrypt
     - some_webserver_role
```

Testing
-------

Before running `vagrant provision` or `vagrant up`, make sure there is a vagrant-ansible.vars file with the following content:

``` yaml
le_testing: true
```

This will ensure that the acme testing server is stood up. Then, provision the vm. Take any notes about getting coffee seriously.

Then login to the VM, and run the migrate scripts in `/root`. It should work. Assuming the test vhost is test.com, you'd run `/root/migrate-test.com.sh`.

To test that the letsencrypt certs are in place, make sure the following line is in `/etc/hosts`:

``` console
127.0.0.1        localhost test.com 
```

Then run

``` bash
curl -kvI test.com
```
If you see the following line, then it worked.

``` console
*  issuer: CN=h2ppy h2cker fake CA
```

Any subsequent runs of  `/root/migrate-test.com.sh` will greet you with an error message saying you already have a certificate for `test.com`

Dependencies
------------

- A webserver with a systemd unit that supports reloading configuration.
- `geerlingguy.pip`


License
-------

BSD

Author
------

Tag1 Consulting
