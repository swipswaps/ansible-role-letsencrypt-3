%w[80 443].each do |p|
  describe port(p) do
    it { should be_listening }
    its('processes') { should be_in %w[httpd apache2] }
  end
end

describe file('/root/migrate-test.me.sh') do
  it { should exist }
end

describe command('/root/migrate-test.me.sh') do
  its('exit_status') { should eq 0 }
end
