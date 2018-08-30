# frozen_string_literal: true

# This function wraps the upload_file function with a deprecation warning, for backward compatibility.
Puppet::Functions.create_function(:file_upload, Puppet::Functions::InternalFunction) do
  def file_upload(*args)
    executor = Puppet.lookup(:bolt_executor) { nil }
    executor&.report_function_call('file_upload')

    file, line = Puppet::Pops::PuppetStack.top_of_stack

    msg = "The file_upload function is deprecated and will be removed; use upload_file instead"
    Puppet.puppet_deprecation_warning(msg, key: 'bolt-function/file_upload', file: file, line: line)

    call_function('upload_file', *args)
  end
end
