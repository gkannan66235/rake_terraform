require 'ruby_terraform'
require 'spec_helper'

describe RakeTerraform::Tasks::Output do
  include_context :rake

  before(:each) do
    namespace :terraform do
      task :ensure
    end
  end

  it 'adds an output task in the namespace in which it is created' do
    namespace :infrastructure do
      subject.define do |t|
        t.configuration_name = 'network'
        t.source_directory = 'infra/network'
        t.work_directory = 'build'
      end
    end

    expect(Rake::Task['infrastructure:output']).not_to be_nil
  end

  it 'gives the output task a description' do
    namespace :dependency do
      subject.define(configuration_name: 'network') do |t|
        t.source_directory = 'infra/network'
        t.work_directory = 'build'
      end
    end

    expect(Rake::Task["dependency:output"].full_comment)
        .to(eq('Output network using terraform'))
  end

  it 'allows the task name to be overridden' do
    namespace :infrastructure do
      subject.define(name: :output_network) do |t|
        t.configuration_name = 'network'
        t.source_directory = 'infra/network'
        t.work_directory = 'build'
      end
    end

    expect(Rake::Task.task_defined?('infrastructure:output_network'))
        .to(be(true))
  end

  it 'allows multiple output tasks to be declared' do
    namespace :infra1 do
      subject.define do |t|
        t.configuration_name = 'network'
        t.source_directory = 'infra/network'
        t.work_directory = 'build'
      end
    end

    namespace :infra2 do
      subject.define do |t|
        t.configuration_name = 'database'
        t.source_directory = 'infra/network'
        t.work_directory = 'build'
      end
    end

    infra1_output = Rake::Task['infra1:output']
    infra2_output = Rake::Task['infra2:output']

    expect(infra1_output).not_to be_nil
    expect(infra2_output).not_to be_nil
  end

  it 'depends on the terraform:ensure task by default' do
    namespace :infrastructure do
      subject.define do |t|
        t.configuration_name = 'network'
        t.source_directory = 'infra/network'
        t.work_directory = 'build'
      end
    end

    expect(Rake::Task['infrastructure:output'].prerequisite_tasks)
        .to(include(Rake::Task['terraform:ensure']))
  end

  it 'depends on the provided task if specified' do
    namespace :tools do
      namespace :terraform do
        task :ensure
      end
    end

    namespace :infrastructure do
      subject.define(ensure_task_name: 'tools:terraform:ensure') do |t|
        t.configuration_name = 'network'
        t.source_directory = 'infra/network'
        t.work_directory = 'build'
      end
    end

    expect(Rake::Task['infrastructure:output'].prerequisite_tasks)
        .to(include(Rake::Task['tools:terraform:ensure']))
  end

  it 'configures the task with the provided arguments if specified' do
    argument_names = [:deployment_identifier, :region]

    namespace :infrastructure do
      subject.define(argument_names: argument_names) do |t|
        t.configuration_name = 'network'
        t.source_directory = 'infra/network'
        t.work_directory = 'build'
      end
    end

    expect(Rake::Task['infrastructure:output'].arg_names)
        .to(eq(argument_names))
  end

  it 'cleans the work directory' do
    source_directory = 'infra/network'
    work_directory = 'build'
    configuration_directory = "#{work_directory}/#{source_directory}"

    subject.define do |t|
      t.configuration_name = 'network'
      t.source_directory = source_directory
      t.work_directory = work_directory
    end

    stub_puts
    stub_chdir
    stub_cp_r
    stub_mkdir_p
    stub_ruby_terraform

    expect(RubyTerraform).to(receive(:clean))
        .with(directory: configuration_directory)

    Rake::Task['output'].invoke
  end

  it 'recursively makes the parent of the configuration directory' do
    source_directory = 'infra/network'
    work_directory = 'build'
    parent_of_configuration_directory = "#{work_directory}/infra"

    subject.define do |t|
      t.configuration_name = 'network'
      t.source_directory = source_directory
      t.work_directory = work_directory
    end

    stub_puts
    stub_chdir
    stub_cp_r
    stub_mkdir_p
    stub_ruby_terraform

    expect_any_instance_of(FileUtils)
        .to(receive(:mkdir_p))
        .with(parent_of_configuration_directory, anything)

    Rake::Task['output'].invoke
  end

  it 'recursively copies the source directory to the work directory' do
    source_directory = 'infra/network'
    work_directory = 'build'
    configuration_directory = "#{work_directory}/#{source_directory}"

    subject.define do |t|
      t.configuration_name = 'network'
      t.source_directory = source_directory
      t.work_directory = work_directory
    end

    stub_puts
    stub_chdir
    stub_cp_r
    stub_mkdir_p
    stub_ruby_terraform

    expect_any_instance_of(FileUtils)
        .to(receive(:cp_r))
        .with(source_directory, configuration_directory, anything)

    Rake::Task['output'].invoke
  end

  it 'switches to the work directory' do
    source_directory = 'infra/network'
    work_directory = 'build'
    configuration_directory = "#{work_directory}/#{source_directory}"

    subject.define do |t|
      t.configuration_name = 'network'
      t.source_directory = source_directory
      t.work_directory = work_directory
    end

    stub_puts
    stub_chdir
    stub_cp_r
    stub_mkdir_p
    stub_ruby_terraform

    expect(Dir).to(receive(:chdir)).with(configuration_directory).and_yield

    Rake::Task['output'].invoke
  end

  it 'outputs with terraform for the provided configuration directory' do
    source_directory = 'infra/network'
    work_directory = 'build'

    subject.define do |t|
      t.configuration_name = 'network'
      t.source_directory = source_directory
      t.work_directory = work_directory
    end

    stub_puts
    stub_chdir
    stub_cp_r
    stub_mkdir_p
    stub_ruby_terraform

    expect(RubyTerraform).to(receive(:output))

    Rake::Task['output'].invoke
  end

  it 'uses the provided source directory factory when supplied' do
    bucket_name = 'bucket-from-args'
    configuration_name = 'network'
    source_directory = "#{bucket_name}/#{configuration_name}"
    configuration_directory = "build/#{bucket_name}/#{configuration_name}"

    subject.define(argument_names: [:bucket_name]) do |t, args|
      t.configuration_name = configuration_name
      t.source_directory = "#{args.bucket_name}/#{t.configuration_name}"
      t.work_directory = 'build'
    end

    stub_puts
    stub_chdir
    stub_cp_r
    stub_mkdir_p
    stub_ruby_terraform

    expect_any_instance_of(FileUtils)
        .to(receive(:cp_r))
        .with(source_directory, configuration_directory, anything)

    Rake::Task['output'].invoke(bucket_name)
  end

  it 'uses the provided state file when present' do
    state_file = 'some/state.tfstate'

    subject.define do |t|
      t.configuration_name = 'network'
      t.source_directory = 'infra/network'
      t.work_directory = 'build'

      t.state_file = state_file
    end

    stub_puts
    stub_chdir
    stub_cp_r
    stub_mkdir_p
    stub_ruby_terraform

    expect(RubyTerraform)
        .to(receive(:output)
                .with(hash_including(state: state_file)))

    Rake::Task['output'].invoke
  end

  it 'uses the provided state file factory when present' do
    subject.define(argument_names: [:deployment_identifier]) do |t, args|
      t.configuration_name = 'network'
      t.source_directory = 'infra/network'
      t.work_directory = 'build'

      t.state_file =
        "path/to/state/#{args.deployment_identifier}/" +
            "#{t.configuration_name}.tfstate"
    end

    stub_puts
    stub_chdir
    stub_cp_r
    stub_mkdir_p
    stub_ruby_terraform

    expect(RubyTerraform)
        .to(receive(:output)
                .with(hash_including(state: "path/to/state/staging/network.tfstate")))

    Rake::Task['output'].invoke('staging')
  end

  it 'passes a no_color parameter of false to output by default' do
    subject.define do |t|
      t.configuration_name = 'network'
      t.source_directory = 'infra/network'
      t.work_directory = 'build'
    end

    stub_puts
    stub_chdir
    stub_cp_r
    stub_mkdir_p
    stub_ruby_terraform

    expect(RubyTerraform)
        .to(receive(:output)
                .with(hash_including(no_color: false)))

    Rake::Task['output'].invoke
  end

  it 'passes the provided value for the no_color parameter to output when present' do
    subject.define do |t|
      t.configuration_name = 'network'
      t.source_directory = 'infra/network'
      t.work_directory = 'build'
      t.no_color = true
    end

    stub_puts
    stub_chdir
    stub_cp_r
    stub_mkdir_p
    stub_ruby_terraform

    expect(RubyTerraform)
        .to(receive(:output)
                .with(hash_including(no_color: true)))

    Rake::Task['output'].invoke
  end

  def stub_puts
    allow_any_instance_of(Kernel).to(receive(:puts))
  end

  def stub_chdir
    allow(Dir).to(receive(:chdir)).and_yield
  end

  def stub_cp_r
    allow_any_instance_of(FileUtils).to(receive(:cp_r))
  end

  def stub_mkdir_p
    allow_any_instance_of(FileUtils).to(receive(:mkdir_p))
  end

  def stub_ruby_terraform
    allow(RubyTerraform).to(receive(:clean))
    allow(RubyTerraform).to(receive(:init))
    allow(RubyTerraform).to(receive(:output))
  end
end
