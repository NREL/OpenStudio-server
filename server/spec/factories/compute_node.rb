FactoryGirl.define do
  factory :compute_node do
    node_type "server"
    ip_address "localhost"
    hostname "os-server"
    cores "2"
    valid true
  end
end

