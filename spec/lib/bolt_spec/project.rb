# frozen_string_literal: true

module BoltSpec
  module Project
    def with_project(name = 'project')
      Dir.mktmpdir(nil, Dir.pwd) do |tmpdir|
        @tmpdir       = Pathname.new(tmpdir).expand_path
        @project_path = (@tmpdir + name).expand_path
        @config_path  = (@project_path + 'bolt-project.yaml').expand_path

        FileUtils.mkdir_p(@project_path)
        File.write(@config_path, project_config.to_yaml)
        yield
      end
    end

    def in_project(name = 'project')
      with_project(name) do
        Dir.chdir(@project_path) do
          yield
        end
      end
    end

    def with_boltdir
      with_project do
        @project_path += 'Boltdir'
        FileUtils.mkdir_p(@project_path)
        yield
      end
    end

    def tmpdir
      @tmpdir
    end

    def project_path
      @project_path
    end

    def config_path
      @config_path
    end

    def project_config
      {}
    end

    def project
      Bolt::Project.create_project(project_path)
    end

    def delete_config
      FileUtils.rm(@config_path)
    end
  end
end
