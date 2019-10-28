%w[80 443].each do |p|
  describe port(p) do
    it { should be_listening }
    its('processes') { should be_in %w[httpd apache2] }
  end
end

describe file('/root/migrate-test.me.sh') do
  it { should exist }
  its('owner') { should eq 'root' }
  its('group') { should eq 'root' }
end

describe port(4000) do
  its('processes') { should include 'docker-proxy-cu' }
end

# This will get the certificate from the acme test server
describe command('/root/migrate-test.me.sh') do
  its('exit_status') { should eq 0 }
end

%w[80 443].each do |p|
  describe port(p) do
    it { should be_listening }
    its('processes') { should be_in %w[httpd apache2] }
  end
end

describe(crontab('root').where { command =~ /certbot renew/ }) do
  its('minutes') { should cmp '7' }
  its('hours') { should cmp '7' }
  its('days') { should include '*/7' }
  its('months') { should include '*' }
  its('weekdays') { should include '*' }
end
