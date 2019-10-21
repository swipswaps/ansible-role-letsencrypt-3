# Letsencrypt

Initially configures self-signed certificates and generates scripts to migrate to LetsEncrypt certificates on any webserver or
certificate-requiring HTTP-based software. The webserver/software will need to be configured to use the certificates, chains, and keys in
`/etc/letsencrypt/live/<domain>/{chain,privkey,cert}.pem`

When you're ready to switch over to LetsEncrypt, just run the templated migration script for the vhost as `root`. It is
built to handle failure, and will backup the certificates, chains, and keys and restore them if anything goes wrong.

This role is currently best used on low-traffic webserving stacks where SSL/TLS and webserving are on the same machine.
It was created because we usually only run ansible against our managed servers when a change is made, so using the
included ACME modules was not a good option. We wanted the option to create self-signed certificates at first then migrate
to LetsEncrypt easily during client webapp migrations.

This role only supports the http-01 ACME challenge. It has been tested on Centos7 and Ubuntu18.04. It will probably work
on all RHEL and most Debian-based distributions.

## Software Dependencies

The only hard dependency for this role is `pip`. It is used to install docker-compose and certbot.

Optionally, `docker` and `docker-compose` are dependencies if you want to manage those yourself. You might want to do this
if you're running containers and install a specific version of `docker` and `docker-compose`. If this is the case, set
`le_manage_docker` to `false` and this role will not try to install `docker` and `docker-compose`. This is only relevant
if you're running in testing mode, with `le_testing` set to `true`.

## Usage

This role sets up self-signed certificate, key, and chain files for each virtual host that is defined in the `le_hosts`
variable. Then, it generates a "migration script" for each vhost that can be ran once DNS is updated or the
.acme-challenge routes are proxied to the machine this is ran against. This role can be used with any webserver or
software that needs certificates to run properly. Set `le_webserver_service` to whatever service you want to restart
after installing self-signed or LetsEncrypt certificates.

```yaml
le_hosts:
  - domain: mywebsite.mydomain
    directory: /var/www/mywebsite.mydomain
``` 

If you have an Nginx server that receives requests for the domain `mywebsite.mydomain` with `mywebsite.mydomain/`
serving files from `/var/www/mywebsite.mydomain`, you'd set `le_hosts` like this. 

The `directory` for each host needs to match the path that requests to `/` go to for that particular domain. If this
is wrong, the ACME challenge will fail.  

In the case of the above example, the tag1-letsencrypt role will read the
`le_hosts` variable to create the following changes on the VM:

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
    - Reloads webserver serivce
       - Restores `/etc/letsencrypt` from backup if the reload fails then reloads the webserver again

## Role Variables

| Variables | Description | Default | Required |
|-|-|-|-|
|`le_admin_mailto`|Email address for LetsEncrypt to send notices about protocol changes and expiry notices|`root`| Yes|
|`le_certbot_venv`|Path to python virtualenv that contains certbot and its dependencies|`/root/.certbot_virtualenv`| No|
|`le_hosts`|List of hosts to generate self-signed certs and migration scripts for. This array of hashes only needs to have the `domain` and `directory` variables set. See the example playbook.|`None`| Yes|
|`le_manage_docker`| Whether to install docker in this role or not. Docker is only installed for the test acme server when `le_testing` is `true`| `true`| No|
|`le_migrate_script_basepath`|Directory to store the migration scripts.|`/root/`| No|
|`le_migrate_script_prefix`|Prefix to script filenames.|`migrate`| No|
|`le_selfsign_base_dir`|Directory to store all files related to self-signing certificates.|`/etc/ssl/`| No|
|`le_selfsign_key_name`|Name of file in `le_selfsign_base_dir` to do all signing with.|`self-sign-root.pem`| No|
|`le_selfsign_chain_name`|Name of chain file in `le_selfsign_base_dir`. It contains no private information.|`fake-chain.pem`| No|
|`le_testing`|Determines whether a acme testing server gets stood up.| `false`| No|
|`le_testing_dir`|Path to clone ACME server code.|`/tmp/boulder`| No|
|`le_webserver_service`|Name of systemd unit to reload after acme challenge.|`httpd` on RHEL/CentOS `apache2` on Debian/Ubuntu| No|

## Example Playbook

Run the role with the `le_testing` variable set to `true` in testing, `false` in production. The `le_testing` variable will setup a local
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

le_hosts:
  - domain: test.com
    directory: /var/www/html
```

In a tasks file:

```YAML
- name: Setup letsencrypt
  # Most webservers fail to start the webserver if there are no certs installed yet.
  import_role: 
    name: tag1consulting.letsencrypt

- name: Setup webserver
  # Now that there are certs and keys, the webserver can be brought up
  import_role:
    name: some_webserver_role
```

**OR**

In a playbook:

```YAML
- hosts: webservers
  roles:
     - tag1consulting.letsencrypt
     - some_webserver_role
```

## Testing

Tests are written for use with [Molecule](https://molecule.readthedocs.io/en/stable/installation.html)
You can run tests locally against the scenarios `centos7` and `ubuntu18.04`. All scenarios set `le_testing` to true.

Run `molecule verify <scenario>` before pushing your changes.

## License

BSD

## Author

Tag1 Consulting
