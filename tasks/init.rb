#!/opt/puppetlabs/puppet/bin/ruby

require 'base64'
require 'json'
require 'open3'
require 'tempfile'

def write_file(path, content, mode)
  source = Base64.decode64(content)
  File.open(path, 'w') do |f|
    f.chmod(mode)
    f.write(source)
  end
  { success: true }
end

def command(command)
  stdout, stderr, p = Open3.capture3(command)
  { stdout: stdout,
    stderr: stderr,
    exit_code: p.exitstatus }
end

def script(content)
  tf = Tempfile.new('bolt_script')
  source = Base64.decode64(content)
  tf.chmod(0o700)
  tf.write(source)
  tf.close
  command(tf.path)
end

params = JSON.parse(STDIN.read)

result = case params['action']
         when 'command'
           command(params['command'])
         when 'upload'
           write_file(params['path'], params['content'], params['mode'])
         when 'script'
           script(params['content'])
         end

puts result.to_json
