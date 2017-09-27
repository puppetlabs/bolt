require 'spec_helper'
require 'bolt/result'

describe "Bolt::Result" do
  def make_output(stdout, stderr = '')
    res = Bolt::ResultOutput.new
    res.stdout.puts stdout
    res.stderr.puts stderr
    res
  end

  def success(stdout)
    outp = make_output(stdout)
    Bolt::Success.new("fake success", outp).result_hash
  end

  def failure(stdout, stderr = '', exitcode = 1)
    outp = make_output(stdout, stderr)
    Bolt::Failure.new(exitcode, outp).result_hash
  end

  describe "result_hash" do
    it "parses stdout as JSON" do
      exp = { "json" => "parsed" }
      res = success(exp.to_json)
      expect(res).to eq(exp)
    end

    it "puts unparseable stdout into _output" do
      res = success('this worked')
      expect(res).to eq("_output" => "this worked\n")
    end

    it "preserves an explicit _error and other output" do
      exp = {
        "things" => [1, 2, 3],
        "_error" => { "msg" => "not like this" }
      }
      res = failure(exp.to_json)
      expect(res).to eq(exp)
    end

    it "synthesizes an _error when none is given" do
      out = { "things" => [1, 2, 3] }
      err = { "_error" =>
        {
          "kind" => "task_error",
          "msg" => "Task exited with 1",
          "details" => { "exit_code" => 1 }
        } }
      exp = out.dup.merge(err)
      res = failure(out.to_json)
      expect(res).to eq(exp)
    end
  end
end
