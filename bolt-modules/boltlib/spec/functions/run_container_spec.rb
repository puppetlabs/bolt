# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/container_result'

describe 'run_container' do
  let(:executor) { Bolt::Executor.new }
  let(:tasks_enabled) { true }
  let(:user) { Bolt::Util.windows? ? "user manager\\containeradministrator\r" : 'root' }

  # So that this can be called in the before block
  def image
    @image ||= if Bolt::Util.windows?
                 'mcr.microsoft.com/windows/servercore:ltsc2022'
               else
                 'ubuntu:20.04'
               end
  end

  before :all do
    # Ensure that the Docker image we're using is available
    images, _status = Open3.capture2e("docker images #{image}")
    # If the output doesn't include the name of the repository (which is
    # separate from the tag in output), download it
    unless images.include?(image.split(":")[0])
      begin
        `docker pull #{image}`
      rescue StandardError => e
        raise "Error download Docker image #{image} to execute run_container tests with: #{e}"
      end
    end
  end

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor) do
      example.run
    end
  end

  context 'it runs the docker command' do
    let(:mock_status) { mock('Process::Status') }
    let(:value) do
      { 'stdout' => "#{user}\n",
        'stderr' => "",
        'exit_code' => 0 }
    end
    let(:result) { Bolt::ContainerResult.new(value, object: image) }

    before :each do
      Puppet.features.stubs(:bolt?).returns(true)
      mock_status.stubs(:exitstatus).returns(0)
      mock_status.stubs(:success?).returns(true)
    end

    it 'with given image and command' do
      # This image should be cached in Github Actions environments, so we don't
      # get downloading output
      is_expected.to run
        .with_params(image, { 'cmd' => 'whoami', 'rm' => true })
        .and_return(result)
    end

    context 'with errors' do
      before :each do
        mock_status.stubs(:exitstatus).returns(127)
        mock_status.stubs(:success?).returns(false)
      end

      let(:msg) {
        "docker: Error response from daemon: OCI runtime create failed: " \
                  "container_linux.go:367: starting container process caused: exec: " \
                  "\"foo\": executable file not found in $PATH: unknown.\n"
      }
      let(:value) do
        { "_error" =>
         { "kind" => "puppetlabs.tasks/container-error",
           "issue_code" => "CONTAINER_ERROR",
           "msg" => "Error running container '#{image}': #{msg}",
           "details" => { "exit_code" => 127 } } }
      end

      it 'raises an error if the container fails' do
        is_expected.to run
          .with_params(image, { 'cmd' => 'foo', 'rm' => true })
          .and_raise_error(Bolt::ContainerFailure, /Running container '#{image}' failed/)
      end

      it 'returns a ContainerResult with errors with _catch_errors' do
        Bolt::Util.expects(:exec_docker)
                  .with(%W[run --rm #{image} foo])
                  .returns(["", msg, mock_status])

        is_expected.to run
          .with_params(image, { 'cmd' => 'foo',
                                '_catch_errors' => true,
                                'rm' => true })
          .and_return(result)
      end
    end

    context 'with options' do
      it 'with given image and specified port' do
        Bolt::Util.expects(:exec_docker)
                  .with(%W[run -p 80:80 --rm #{image} whoami])
                  .returns(["#{user}\n", "", mock_status])

        is_expected.to run
          .with_params(image, { 'cmd' => 'whoami',
                                'ports' => { 80 => 80 },
                                'rm' => true })
          .and_return(result)
      end

      context 'with mounted volumes' do
        let(:src) { File.expand_path('.') }
        let(:value) do
          { 'stdout' => "Rakefile\nlib\nspec\ntypes\n",
            'stderr' => "",
            'exit_code' => 0 }
        end
        let(:dest) { '/volume_mount' }

        it 'with given image and specified volumes' do
          Bolt::Util.expects(:exec_docker)
                    .with(%W[run -v #{src}:#{dest} --rm #{image} ls /volume_mount])
                    .returns([value['stdout'], "", mock_status])

          is_expected.to run
            .with_params(image, { 'cmd' => "ls #{dest}",
                                  'rm' => true,
                                  'volumes' => { src => dest } })
            .and_return(result)
        end
      end

      context 'with env_vars' do
        let(:env_vars) { { 'FRUIT' => { 'apple' => 'banana' } } }
        let(:value) do
          { 'stdout' => env_vars['FRUIT'],
            'stderr' => "",
            'exit_code' => 0 }
        end

        it 'transforms values to json' do
          Bolt::Util.expects(:exec_docker)
                    .with(%W[run --env FRUIT={"apple":"banana"} --rm #{image} echo $FRUIT])
                    .returns([env_vars['FRUIT'], "", mock_status])

          is_expected.to run
            .with_params(image, { 'cmd' => 'echo $FRUIT',
                                  'env_vars' => env_vars,
                                  'rm' => true })
            .and_return(result)
        end
      end

      it 'raises validation errors with invalid options' do
        is_expected.to run
          .with_params(image, { 'cmd' => 'whoami', 'ports' => true, 'rm' => true })
          .and_raise_error(Bolt::ValidationError, /Option 'ports' must be a hash. Received/)
      end
    end

    it 'reports the call to analytics' do
      executor.expects(:report_function_call).with('run_container')

      is_expected.to run
        .with_params(image, { 'cmd' => 'whoami', 'rm' => true })
        .and_return(result)
    end

    context 'without tasks enabled' do
      let(:tasks_enabled) { false }

      it 'fails and reports that run_container is not available' do
        is_expected.to run
          .with_params(image, { 'cmd' => 'whoami' })
          .and_raise_error(/Plan language function 'run_container' cannot be used/)
      end
    end
  end
end
