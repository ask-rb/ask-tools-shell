# frozen_string_literal: true

# Persistent Ruby kernel for Ask::Tools::Shell::Repl.
#
# A standalone plain-Ruby script run as a long-lived subprocess. Reads framed
# JSON requests from stdin, evaluates each snippet into a persistent binding,
# and writes a framed JSON response to stdout.
#
# Protocol (newline-delimited JSON):
#   request:  {"id": 1, "code": "1 + 1"}
#   response: {"id": 1, "result": "2", "stdout": "", "stderr": "", "error": null}
#
# The binding persists across requests, so locals, requires, and defined
# methods survive between calls. stdout/stderr are captured per evaluation.

require "json"
require "stringio"

# Die immediately on TERM (sent by the parent to shut the session down).
# exit! bypasses the rescue Exception below, which would otherwise swallow
# the SignalException raised mid-eval and keep the kernel alive.
trap("TERM") { exit!(0) }

def read_frame
  line = $stdin.gets
  return nil if line.nil?

  JSON.parse(line)
rescue JSON::ParserError
  { "error" => "invalid request frame" }
end

def write_frame(frame)
  $stdout.puts(JSON.generate(frame))
  $stdout.flush
end

def capture_output
  old_out = $stdout
  old_err = $stderr
  out = StringIO.new
  err = StringIO.new
  $stdout = out
  $stderr = err
  yield
  [out.string, err.string]
ensure
  $stdout = old_out
  $stderr = old_err
end

def safe_inspect(value)
  value.inspect
rescue StandardError
  "#<#{value.class}>"
end

binding = TOPLEVEL_BINDING

loop do
  request = read_frame
  break if request.nil?

  id = request["id"]
  code = request["code"].to_s

  result = nil
  stdout = ""
  stderr = ""
  error = nil

  begin
    stdout, stderr = capture_output do
      result = binding.eval(code)
    end
  rescue Exception => e # rubocop:disable Lint/RescueException
    error = "#{e.class}: #{e.message}"
    trace = (e.backtrace || []).first(10).join("\n")
    stderr += trace
  end

  write_frame(
    "id" => id,
    "result" => safe_inspect(result),
    "stdout" => stdout,
    "stderr" => stderr,
    "error" => error
  )
end
