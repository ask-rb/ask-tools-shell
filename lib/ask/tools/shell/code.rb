# frozen_string_literal: true

require "open3"
require "tmpdir"

module Ask
  module Tools
    # Write and execute Ruby code in a subprocess.
    # Runs in a temp directory via ruby -e.
    class Code < Ask::Tool
      description "Write and execute Ruby code in a subprocess. " \
                   "Returns stdout, stderr, and exit code. " \
                   "Uses gems already available in the environment."

      param :code, type: :string, desc: "Ruby source code to execute", required: true

      MAX_OUTPUT_SIZE = 102_400

      def execute(code:)
        Dir.mktmpdir("ask_code") do |_dir|
          stdout = StringIO.new
          stderr = StringIO.new
          exit_code = -1

          begin
            Open3.popen3("ruby", "-e", code, chdir: Dir.pwd) do |stdin, out, err, wait_thr|
              stdin.close

              threads = [
                Thread.new { IO.copy_stream(out, stdout) rescue nil },
                Thread.new { IO.copy_stream(err, stderr) rescue nil }
              ]

              threads.each(&:join)
              exit_code = wait_thr.value.exitstatus
            end
          rescue => e
            return Ask::Result.error(message: "Code execution failed: #{e.message}",
                                     metadata: { stdout: stdout.string, stderr: stderr.string })
          end

          out_text = stdout.string
          err_text = stderr.string

          if out_text.length > MAX_OUTPUT_SIZE
            header = "[Output truncated to #{MAX_OUTPUT_SIZE / 1024}KB]\n"
            out_text = "#{header}#{out_text[-(MAX_OUTPUT_SIZE - header.length)..]}"
          end

          Ask::Result.ok(data: {
            stdout: out_text,
            stderr: err_text,
            exit_code: exit_code
          })
        end
      end
    end
  end
end
