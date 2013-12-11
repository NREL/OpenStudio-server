FactoryGirl.define do
  factory :compute_node do
    node_type "server"
    ip_address "192.168.33.10"
    hostname "os-server"
    cores "2"
    valid true
  end
end

