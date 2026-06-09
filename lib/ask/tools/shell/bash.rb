# frozen_string_literal: true

require "open3"
require "tempfile"
require "stringio"
require "tmpdir"

module Ask
  module Tools
    # Execute shell commands in a sandboxed environment.
    # Returns stdout, stderr, exit code, and a timed_out flag.
    # Output is truncated to 100KB.
    class Bash < Ask::Tool
      description "Execute a bash command in a sandboxed environment. " \
                   "Returns stdout, stderr, and exit code. " \
                   "Output is truncated to 100KB."

      param :command, type: :string, desc: "The bash command to execute", required: true
      param :timeout, type: :integer, desc: "Timeout in seconds", required: false
      param :workdir, type: :string, desc: "Working directory", required: false

      MAX_OUTPUT_SIZE = 102_400

      def execute(command:, timeout: 30, workdir: nil)
        Dir.mktmpdir("ask_bash") do |dir|
          workdir ||= dir

          stdout = StringIO.new
          stderr = StringIO.new
          timed_out = false
          exit_code = -1

          begin
            Open3.popen3("bash", "-c", command, chdir: workdir) do |stdin, out, err, wait_thr|
              stdin.close

              threads = [
                Thread.new { IO.copy_stream(out, stdout) rescue nil },
                Thread.new { IO.copy_stream(err, stderr) rescue nil }
              ]

              unless wait_thr.join(timeout)
                Process.kill("-KILL", wait_thr.pid) rescue nil
                timed_out = true
              end

              threads.each(&:join)
              exit_code = timed_out ? -1 : wait_thr.value.exitstatus
            end
          rescue => e
            return Ask::Result.error(message: "Bash execution failed: #{e.message}",
                                     metadata: { stdout: stdout.string, stderr: stderr.string })
          end

          out_text = stdout.string
          err_text = stderr.string

          if out_text.length > MAX_OUTPUT_SIZE
            header = "[Output truncated to #{MAX_OUTPUT_SIZE / 1024}KB]\n"
            out_text = "#{header}#{out_text[-(MAX_OUTPUT_SIZE - header.length)..]}"
          end

          if err_text.length > MAX_OUTPUT_SIZE
            header = "[Error output truncated to #{MAX_OUTPUT_SIZE / 1024}KB]\n"
            err_text = "#{header}#{err_text[-(MAX_OUTPUT_SIZE - header.length)..]}"
          end

          Ask::Result.ok(data: {
            stdout: out_text,
            stderr: err_text,
            exit_code: exit_code,
            timed_out: timed_out
          })
        end
      end
    end
  end
end
