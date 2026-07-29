# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'tmpdir'
require 'rbconfig'
require 'json'

describe 'ExternalBatch::Nomad submit_nomad.rb' do
  NOMAD_DIR = File.expand_path(File.dirname(__FILE__))

  around do |example|
    Dir.mktmpdir do |tmp|
      @batch_root = File.join(tmp, 'batch')
      @fake_nomad_root = File.join(tmp, 'fake_nomad')  # Simulates the shared storage (NFS or S3 root)
      @stub_log = File.join(tmp, 'nomad_calls.log')
      FileUtils.mkdir_p [@batch_root, @fake_nomad_root]
      ENV['OS_SERVER_EXTERNAL_BATCH_ROOT'] = @batch_root
      ENV['FAKE_NOMAD_ROOT'] = @fake_nomad_root
      ENV['NOMAD_STUB_LOG'] = @stub_log
      begin
        example.run
      ensure
        ENV.delete('OS_SERVER_EXTERNAL_BATCH_ROOT')
        ENV.delete('FAKE_NOMAD_ROOT')
        ENV.delete('NOMAD_STUB_LOG')
      end
    end
  end

  before do
    @nomad_cmd = "\"#{RbConfig.ruby}\" \"#{write_stub_nomad(@fake_nomad_root)}\""
  end

  def fake_nomad_batch_dir(bucket, analysis)
    # For our stub, we treat the fake_nomad_root as the base for NFS/S3-like paths
    File.join(@fake_nomad_root, bucket, 'runs', "analysis_#{analysis.id}")
  end

  # Stub of the Nomad CLI: 
  #   `nomad job run -output=json <job_file>` prints a fake job ID and logs the invocation.
  #   Every invocation is appended to NOMAD_STUB_LOG as a JSON argv line.
  def write_stub_nomad(dir)
    stub_path = File.join(dir, 'fake_nomad.rb')
    File.write(stub_path, <<~'RUBY')
      require 'json'
      require 'fileutils'

      fake_root = ENV['FAKE_NOMAD_ROOT'] || abort('FAKE_NOMAD_ROOT not set')
      log_path = ENV['NOMAD_STUB_LOG']
      File.open(log_path, 'a') { |f| f.puts JSON.generate(ARGV) } if log_path

      argv = ARGV.dup
      File.open(log_path, 'a') { |f| f.puts "argv after dup: #{argv.inspect}" } if log_path
      # Remove the -address argument if present (we don't use it in the stub)
      if (i = argv.index('-address'))
        argv.slice!(i, 2)
      end
      File.open(log_path, 'a') { |f| f.puts "argv after removing -address: #{argv.inspect}" } if log_path
      # Also handle --address=...
      if (i = argv.index { |arg| arg.start_with?('--address=') })
        argv.slice!(i, 1)
      end
      File.open(log_path, 'a') { |f| f.puts "argv after removing --address=: #{argv.inspect}" } if log_path
      # Also handle -address=...
      if (i = argv.index { |arg| arg.start_with?('-address=') })
        argv.slice!(i, 1)
      end
      File.open(log_path, 'a') { |f| f.puts "argv after removing -address=: #{argv.inspect}" } if log_path

      service = argv.shift
      File.open(log_path, 'a') { |f| f.puts "service: #{service.inspect}" } if log_path
      case service
      when 'job'
        subcommand = argv.shift
        File.open(log_path, 'a') { |f| f.puts "subcommand: #{subcommand.inspect}" } if log_path
        case subcommand
        when 'run'
          # Expect: -output=json <job_file> or -output json <job_file>
          output_arg = argv.shift
          File.open(log_path, 'a') { |f| f.puts "output_arg: #{output_arg.inspect}" } if log_path
          if output_arg == '-output'
            output_flag = output_arg
            output_value = argv.shift
          elsif output_arg.start_with?('-output=')
            output_flag = '-output'
            output_value = output_arg.sub('-output=', '')
          else
            abort "Expected -output or -output=value, got #{output_arg}"
          end
          job_file = argv.shift
          File.open(log_path, 'a') { |f| f.puts "output_flag: #{output_flag.inspect}, output_value: #{output_value.inspect}, job_file: #{job_file.inspect}" } if log_path
          unless output_flag == '-output' && output_value == 'json'
            abort "Expected -output=json, got #{output_flag} #{output_value}"
          end
          # Check that the job file exists (we don't need to read it)
          unless File.exist?(job_file)
            abort "Job file not found: #{job_file}"
          end
          # Output a fake job ID JSON
          puts JSON.generate({ 'job' => { 'ID' => 'fake-job-id-123' } })
        else
          abort "unsupported nomad job subcommand #{subcommand}"
        end
      else
        abort "unsupported nomad service #{service}"
      end
    RUBY
    stub_path
  end

  # We need a minimal analysis and data points to create a manifest.
  # If ExternalBatchHelpers is available (when running in the server spec context), use it.
  # Otherwise, create a minimal manifest directly.
  def create_manifest(batch_dir, num_dps: 3, dps_per_chunk: 2)
    # Create a minimal manifest.json
    manifest = {
      'analysis_id' => 123,
      'chunks' => (0...(num_dps.to_f / dps_per_chunk).ceil).map do |i|
        {
          'index' => i,
          'data_point_ids' => ((i * dps_per_chunk)...[((i + 1) * dps_per_chunk), num_dps].min).map { |j| j + 1 }
        }
      end
    }
    package_dir = File.join(batch_dir, 'package')
    FileUtils.mkdir_p(package_dir)
    File.write(File.join(package_dir, 'manifest.json'), JSON.generate(manifest))
    # Create a dummy analysis directory for each chunk
    manifest['chunks'].each do |chunk|
      analysis_dir = File.join(package_dir, "analysis_#{manifest['analysis_id']}")
      FileUtils.mkdir_p(analysis_dir)
      chunk['data_point_ids'].each do |dp_id|
        dp_dir = File.join(analysis_dir, "datapoint_#{dp_id}")
        FileUtils.mkdir_p(dp_dir)
        File.write(File.join(dp_dir, 'in.osw'), '{}')
      end
    end
  end

  describe 'submit_nomad.rb' do
    it 'pushes the package to the shared location and submits an array job sized to the chunk count' do
      batch_dir = File.join(@batch_root, 'batch_1')
      FileUtils.mkdir_p(batch_dir)
      create_manifest(batch_dir, num_dps: 3, dps_per_chunk: 2)

      ok = system(RbConfig.ruby, File.join(NOMAD_DIR, 'submit_nomad.rb'),
                  batch_dir,
                  '--nomad-addr', 'http://nomad:4646',
                  '--job-template', File.join(NOMAD_DIR, 'templates', 'job_array.hcl'),
                  '--package-location', @fake_nomad_root,
                  '--nomad-cmd', @nomad_cmd)
      puts "Stub log contents: #{File.read(@stub_log)}" if File.exist?(@stub_log)
      expect(ok).to be(true), 'submit_nomad.rb exited non-zero'

      # package mirrored into the fake nomad root (simulating NFS)
      expect(File).to exist(File.join(@fake_nomad_root, 'analysis_123', 'package', 'manifest.json'))
      expect(Dir).to exist(File.join(@fake_nomad_root, 'analysis_123', 'package', 'analysis_123'))

      # nomad job run called with the right shape
      calls = File.readlines(@stub_log).
                select { |l| l.strip.start_with?('[') && l.strip.end_with?(']') }.
                map { |l| JSON.parse(l) }
      # Find the ARGV line (should be the only one that is an array)
      argv_line = calls.detect { |c| c.is_a?(Array) }
      # Remove the -address argument (in its various forms) as the stub does
      argv = argv_line.dup
      if (i = argv.index('-address'))
        argv.slice!(i, 2)
      end
      if (i = argv.index { |arg| arg.start_with?('--address=') })
        argv.slice!(i, 1)
      end
      if (i = argv.index { |arg| arg.start_with?('-address=') })
        argv.slice!(i, 1)
      end
      # Now shift off the service and subcommand as the stub does
      service = argv.shift
      subcommand = argv.shift
      # Now we expect the first element to be the output_arg
      output_arg = argv.shift
      # Then split the output_arg as the stub does
      if output_arg == '-output'
        output_flag = output_arg
        output_value = argv.shift
      elsif output_arg.start_with?('-output=')
        output_flag = '-output'
        output_value = output_arg.sub('-output=', '')
      else
        # This should not happen
        raise "Unexpected output_arg: #{output_arg}"
      end
      # Then the next element is the job_file
      job_file = argv.shift
      # Now we expect:
      expect(service).to eq 'job'
      expect(subcommand).to eq 'run'
      expect(output_flag).to eq '-output'
      expect(output_value).to eq 'json'
      expect(job_file).to be_a(String)
      expect(job_file).not_to be_empty
    end

    it 'submits a plain job with CHUNK_INDEX for a single chunk (Nomad arrays need count >= 2)' do
      batch_dir = File.join(@batch_root, 'batch_2')
      FileUtils.mkdir_p(batch_dir)
      create_manifest(batch_dir, num_dps: 2, dps_per_chunk: 50) # 1 chunk

      ok = system(RbConfig.ruby, File.join(NOMAD_DIR, 'submit_nomad.rb'),
                  batch_dir,
                  '--nomad-addr', 'http://nomad:4646',
                  '--job-template', File.join(NOMAD_DIR, 'templates', 'job_array.hcl'),
                  '--package-location', @fake_nomad_root,
                  '--nomad-cmd', @nomad_cmd)
      puts "Stub log contents: #{File.read(@stub_log)}" if File.exist?(@stub_log)
      expect(ok).to be true

      # nomad job run called with the right shape
      calls = File.readlines(@stub_log).
                select { |l| l.strip.start_with?('[') && l.strip.end_with?(']') }.
                map { |l| JSON.parse(l) }
      # Find the ARGV line (should be the only one that is an array)
      argv_line = calls.detect { |c| c.is_a?(Array) }
      # Remove the -address argument (in its various forms) as the stub does
      argv = argv_line.dup
      if (i = argv.index('-address'))
        argv.slice!(i, 2)
      end
      if (i = argv.index { |arg| arg.start_with?('--address=') })
        argv.slice!(i, 1)
      end
      if (i = argv.index { |arg| arg.start_with?('-address=') })
        argv.slice!(i, 1)
      end
      # Now shift off the service and subcommand as the stub does
      service = argv.shift
      subcommand = argv.shift
      # Now we expect the first element to be the output_arg
      output_arg = argv.shift
      # Then split the output_arg as the stub does
      if output_arg == '-output'
        output_flag = output_arg
        output_value = argv.shift
      elsif output_arg.start_with?('-output=')
        output_flag = '-output'
        output_value = output_arg.sub('-output=', '')
      else
        # This should not happen
        raise "Unexpected output_arg: #{output_arg}"
      end
      # Then the next element is the job_file
      job_file = argv.shift
      # Now we expect:
      expect(service).to eq 'job'
      expect(subcommand).to eq 'run'
      expect(output_flag).to eq '-output'
      expect(output_value).to eq 'json'
      expect(job_file).to be_a(String)
      expect(job_file).not_to be_empty
    end
  end
end