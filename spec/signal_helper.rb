# frozen_string_literal: true

RSpec.shared_context 'synchronization thread' do
  let(:sync_thread) { Thread.new { Thread.stop } }

  before :each do
    # make sure the thread is started
    sync_thread
  end

  after :each do
    # cleanup the thread
    sync_thread.kill
  end
end

RSpec.configure do |config|
  # Start a thread used for synchronization between the test code and
  # signal handlers for tests which specify the `:signals_self`
  # metadata.
  config.include_context 'synchronization thread', :signals_self

  # Tests which specify the `:signals_self` metadata send signals to the
  # process executing the tests which causes problems on Windows where the
  # signals are delivered not only to that particular process but rather
  # to the entire process group the process is a member of (i.e. typically
  # to all processes sharing the same Windows console). This may include
  # batch scripts (commonly used to invoke bundler and/or rspec) which
  # handle at least some of the signals by printing:
  #   Terminate batch job (Y/N)?
  # message and waiting for user input. I.e. they effectively hang.
  # To prevent such hangs we skip these tests on Windows unless explicitly
  # enabled by specifying `--tag ~~signals_self` on the rspec command
  # line. Note the double tilde.
  config.filter_run_excluding :signals_self \
    if Gem.win_platform? && !config.exclusion_filter[:'~signals_self']
end
