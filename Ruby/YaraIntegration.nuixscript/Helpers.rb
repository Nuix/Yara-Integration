java_import java.lang.Runtime
java_import java.io.BufferedReader
java_import java.io.InputStreamReader

class Helpers
	# Convenience method for running a command string in the OS
	#
	# @param command [String] Command string to execute
	# @param use_shell [Boolean] When true, will pipe command through CMD /S /C to enable shell features
	# @param working_dir [String] The working direcotry of the subprocess
	def self.run_command(command,use_shell=true,working_dir=nil)
		if working_dir.nil?
			working_dir = File.dirname(__FILE__)
		end

		#puts command

		# Necessary if command take advantage of any shell features such as
		# IO pipining
		if use_shell
			command = "cmd /S /C \"#{command}\""
		end

		# We will return the standard out and standard error lines
		output = {
			:stdout => [],
			:stderr => [],
		}

		begin
			#puts "Executing: #{command}"
			p = Runtime.getRuntime.exec(command,[].to_java(:string),java.io.File.new(working_dir))
			
			# Make sure to sip from standard error stream as it is written to
			std_err_reader = BufferedReader.new(InputStreamReader.new(p.getErrorStream))
			while ((line = std_err_reader.readLine()).nil? == false)
				puts "STDERR: #{line}"
				output[:stderr] << line
			end
			
			p.waitFor
			#puts "Execution completed:"
			# Make sure to sip from standard output stream as it is written to
			reader = BufferedReader.new(InputStreamReader.new(p.getInputStream))
			while ((line = reader.readLine()).nil? == false)
				#puts "STDOUT: #{line}"
				output[:stdout] << line
			end
		rescue Exception => e
			puts e.message
			puts e.backtrace.inspect
		ensure
			p.destroy
		end
		return output
	end
end