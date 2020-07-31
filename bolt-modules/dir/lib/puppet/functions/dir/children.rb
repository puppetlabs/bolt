# frozen_string_literal: true

require 'pathname'

# Returns an array containing all of the filenames except for "." and ".." in the given directory.
Puppet::Functions.create_function(:'dir::children', Puppet::Functions::InternalFunction) do
  # @param dirname Absolute path or Puppet module name.
  # @return Array of files in the given directory.
  # @example List filenames from an absolute path.
  #   dir::children('/home/user/subdir/')
  # @example List filenames from a Puppet file path.
  #   dir::children('puppet_agent')
  dispatch :children do
    scope_param
    required_param 'String', :dirname
    return_type 'Array'
  end

  def children(scope, dirname)
    # Send Analytics Report
    Puppet.lookup(:bolt_executor) {}&.report_function_call(self.class.name)
    modname, subpath = dirname.split(File::SEPARATOR, 2)
    mod_path = scope.compiler.environment.module(modname)&.path

    full_mod_path = File.join(mod_path, subpath || '') if mod_path

    # Expand relative to the project directory if path is relative
    project = Puppet.lookup(:bolt_project_data)
    pathname = Pathname.new(dirname)
    full_dir = pathname.absolute? ? dirname : File.expand_path(File.join(project.path, dirname))

    # Sort for testability
    Dir.children(full_mod_path || full_dir).sort
  end
end
