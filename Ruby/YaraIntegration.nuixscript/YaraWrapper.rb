=begin

usage:  yara [OPTION]... [RULEFILE]... FILE | PID
options:
  -t <tag>                  print rules tagged as <tag> and ignore the rest. Can be used more than once.
  -i <identifier>           print rules named <identifier> and ignore the rest. Can be used more than once.
  -n                        print only not satisfied rules (negate).
  -g                        print tags.
  -m                        print metadata.
  -s                        print matching strings.
  -l <number>               abort scanning after a <number> of rules matched.
  -d <identifier>=<value>   define external variable.
  -r                        recursively search directories.
  -f                        fast matching mode.
  -v                        show version information.

=end

# Class which encapsulates some basic info about a Yara rule file
class YaraRule
	attr_accessor :file_path

	def name
		# Later may try to add logic to attempt to get better name from file
		# possibly from rule metadata?
		return File.basename(@file_path,".*")
	end
end

# Class which wraps interactions with Yara
class YaraWrapper
	attr_accessor :executable_path
	attr_accessor :rule_directory

	# Creates a new instance, specifying where the executable is located
	# and where the rule files are located
	def initialize(executable_path,rule_directory)
		@executable_path = executable_path
		@rule_directory = rule_directory
	end

	# Returns a list of Rule objects representing the rule files located in
	# the rules directory
	def available_rules
		if @rules.nil?
			@rules = []
			Dir.glob(File.join(@rule_directory,"**","*.yar*")).each do |yara_rule_file|
				rule = YaraRule.new
				rule.file_path = yara_rule_file.gsub("/","\\\\")
				@rules << rule
			end
		end
		return @rules
	end

	# Configures the rules to be used when run_rules is called.  Builds an "include" file
	# in the rules directory
	def set_used_rules(rules)
		@used_rules = rules
		include_file = File.join(@rule_directory,"@include.list")
		File.open(include_file,"w:utf-8") do |file|
			@used_rules.each do |rule|
				file.puts "include \"#{rule.file_path}\""
			end
		end
		@base_command = "\"#{@executable_path}\" \"#{include_file}\""
	end

	# Runs Yara with the rules configured by calling set_used_rules against
	# the binary at the specified file path
	def run_rules(input_file)
		command = "#{@base_command} \"#{input_file}\""
		#output = Helpers.run_command(command,true,File.dirname(@rule_directory))
		output = Helpers.run_command(command,true,@rule_directory)
		return output
	end
end