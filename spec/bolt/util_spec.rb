# frozen_string_literal: true

require 'spec_helper'
require 'bolt/pal/yaml_plan'
require 'bolt/util'
require 'bolt_spec/files'

describe Bolt::Util do
  include BoltSpec::Files
  context "when creating a typed name from a modulepath" do
    it "removes init from the typed name" do
      expect(Bolt::Util.module_name('mymod/plans/init.pp')).to eq('mymod')
      expect(Bolt::Util.module_name('mymod/tasks/init.html.erb')).to eq('mymod')
    end

    it "supports extended paths" do
      expect(Bolt::Util.module_name('mymod/plans/subdir/plan.pp')).to eq('mymod::subdir::plan')
    end

    it "splits on the first plans or tasks directory" do
      expect(Bolt::Util.module_name('mymod/plans/plans/myplan.pp')).to eq('mymod::plans::myplan')
      expect(Bolt::Util.module_name('mymod/tasks/plans/mytask.rb')).to eq('mymod::plans::mytask')
    end

    context "#to_code" do
      it "turns DoubleQuotedString types into code strings" do
        string = Bolt::PAL::YamlPlan::DoubleQuotedString.new('doublebubble')
        expect(Bolt::Util.to_code(string)).to eq("\"doublebubble\"")
      end

      context "turns BareString types into code strings" do
        it 'with a preceding variable' do
          string = Bolt::PAL::YamlPlan::BareString.new('$variable')
          expect(Bolt::Util.to_code(string)).to eq('$variable')
        end

        it 'with no variable' do
          string = Bolt::PAL::YamlPlan::BareString.new('nonvariable')
          expect(Bolt::Util.to_code(string)).to eq("'nonvariable'")
        end
      end

      it "turns CodeLiteral types into code strings" do
        string = Bolt::PAL::YamlPlan::CodeLiteral.new('[$codelit].join()')
        expect(Bolt::Util.to_code(string)).to eq('[$codelit].join()')
      end

      it "turns EvaluableString types into code strings" do
        string = Bolt::PAL::YamlPlan::EvaluableString.new('ev@l$tr1ng')
        expect(Bolt::Util.to_code(string)).to eq('ev@l$tr1ng')
      end

      it "turns Hashes into code strings" do
        hash = { 'hash' => Bolt::PAL::YamlPlan::BareString.new('$brown') }
        expect(Bolt::Util.to_code(hash)).to eq("{'hash' => $brown}")
      end

      it "turns Arrays into code string" do
        array = ['a', 'r', 'r', Bolt::PAL::YamlPlan::BareString.new('$a'), 'y']
        expect(Bolt::Util.to_code(array)).to eq("['a', 'r', 'r', $a, 'y']")
      end
    end
  end

  context "when parsing a invalid file" do
    it "raises an error with line and column number if the YAML has a syntax error" do
      contents = <<-YAML
      ---
      version: 2
      config:
        transport: winrm
          ssl-verify: false
          ssl: true
      YAML

      with_tempfile_containing('config_file_test', contents) do |file|
        expect {
          Bolt::Util.read_config_file(file, nil, 'inventory')
        }.to raise_error(Bolt::FileError, /Error at line 2 column 14/)
      end
    end
  end
end
