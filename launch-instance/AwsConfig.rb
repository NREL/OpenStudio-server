require 'rubygems'
require 'yaml'

module OpenStudio
  module Aws
    class Config
      attr_accessor :access_key
      attr_accessor :secret_key

      def initialize(yml_config_file = nil)
        @yml_config_file = yml_config_file
        @config = nil
        if @yml_config_file.nil?
          @yml_config_file = File.join(File.expand_path("~"), "aws_config.yml")
          puts @yml_config_file
          if !File.exists?(@yml_config_file)
            write_config_file
            puts "No Config File in user home directory. A template has been added, please edit and save: #{@yml_config_file}"
            exit 1
          end
        end

        begin
          @config = YAML.load(File.read(@yml_config_file))
          @access_key = @config['access_key_id']
          @secret_key = @config['secret_access_key']
        rescue
          raise "Couldn't read config file #{@yml_config_file}. Delete file then recreate by rerunning script"
        end
      end

      private

      def write_config_file
        File.open(@yml_config_file, 'w') do |f|
          f << "access_key_id: YOUR_ACCESS_KEY_ID\n"
          f << "secret_access_key: YOUR_SECRET_ACCESS_KEY\n"
        end
      end
    end
  end
end
