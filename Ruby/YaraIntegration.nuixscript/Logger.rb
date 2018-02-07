require 'thread'

# Basic logging class.  Logging messages should be thread safe.
class Logger
	attr_accessor :log_file

	def initialize(log_file)
		@log_file = log_file
		j_log_file = java.io.File.new(@log_file)
		j_log_file.getParentFile.mkdirs
		@lock = Mutex.new
	end

	def log(message)
		@lock.synchronize {
			File.open(@log_file,"a:utf-8") do |file|
				file.puts message
			end
		}
	end
end