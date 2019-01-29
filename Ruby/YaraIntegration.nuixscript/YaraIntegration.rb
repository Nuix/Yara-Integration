#==================#
# Bootstrap Nx.jar #
#==================#

script_directory = File.dirname(__FILE__)
require File.join(script_directory,"Nx.jar")
java_import "com.nuix.nx.NuixConnection"
java_import "com.nuix.nx.LookAndFeelHelper"
java_import "com.nuix.nx.dialogs.ChoiceDialog"
java_import "com.nuix.nx.dialogs.CustomDialog"
java_import "com.nuix.nx.dialogs.TabbedCustomDialog"
java_import "com.nuix.nx.dialogs.CommonDialogs"
java_import "com.nuix.nx.dialogs.ProgressDialog"
java_import "com.nuix.nx.dialogs.ProcessingStatusDialog"
java_import "com.nuix.nx.digest.DigestHelper"
java_import "com.nuix.nx.controls.models.Choice"

LookAndFeelHelper.setWindowsIfMetal
NuixConnection.setUtilities($utilities)
NuixConnection.setCurrentNuixVersion(NUIX_VERSION)

#=======================#
# Do some initial setup #
#=======================#

require 'thread'

# Make sure items are selected, in case user somehow was able to run script
# without items selected
if $current_selected_items.nil? || $current_selected_items.size < 1
	CommonDialogs.showError("Items must be selected before running this script!")
	exit 1
end

# Load dependency classes
load File.join(script_directory,"Logger.rb")
load File.join(script_directory,"Helpers.rb")
load File.join(script_directory,"YaraWrapper.rb")

# Define directory containing yara rules and executable
yara_exe_path = File.join(script_directory,"yara_executable","yara.exe").gsub("/","\\\\")
yara_rule_directory = File.join(script_directory,"yara_rules").gsub("/","\\\\")

# Make sure yara exe exists
if !java.io.File.new(yara_exe_path).exists
	CommonDialogs.showError("Unable to locate yara.exe at: #{yara_exe_path}")
	exit 1
end

# Verify that yara.exe is present
if !java.io.File.new(yara_exe_path).exists
	CommonDialogs.showError("Unabled to locate yara.exe at: #{yara_exe_path}")
	exit 1
end

# Create instance of wrapper class which makes it easier to interact with Yara
yara_wrapper = YaraWrapper.new(yara_exe_path,yara_rule_directory)

# Build list of rules located in Yara rule directory
rule_choices = yara_wrapper.available_rules.map{|r|Choice.new(r,r.name)}

# Options for whether descendants are automatically brought in
resolved_items_choices = {
	"Only Selected Items" => {:include_descendants => false},
	"Selected Items and Descendants" => {:include_descendants => true},
}

# Make sure there is at least 1 yara rule available
if rule_choices.size < 1
	CommonDialogs.showError("Found no Yara rule files at: #{yara_rule_directory}")
	exit 1
end

# Build timestamp to use in default log file names
file_timestamp = Time.now.strftime("%Y%m%d_%H%M%S")

# Determine where the case is located for default log directory
case_location = $current_case.getLocation.getPath

# Make sure there is at least 1 yara rule to show the user
if rule_choices.size < 1
	CommonDialogs.showError("Unable to locate Yara rule files in the rule file directory: #{yara_rule_directory}")
	exit 1
end

#============================#
# Build the settings dialogs #
#============================#
dialog = TabbedCustomDialog.new("Yara Integration")

main_tab = dialog.addTab("main_tab","Main")
main_tab.appendHeader("Selected Items: #{$current_selected_items.size}")
main_tab.appendComboBox("resolved_items_choice","Items to Scan",resolved_items_choices.keys)
main_tab.appendSpinner("yara_concurrency","Concurrent Yara Processes",1,1,100)
main_tab.appendDirectoryChooser("temp_directory","Temp Directory")
main_tab.setText("temp_directory","C:\\Temp\\Yara")
main_tab.appendSaveFileChooser("log_file","Log File","Log File","txt")
main_tab.appendSaveFileChooser("error_log_file","Error Log File","Log File","txt")
main_tab.setText("log_file",File.join(case_location,"YaraReports","YaraScan_#{file_timestamp}.txt"))
main_tab.setText("error_log_file",File.join(case_location,"YaraReports","YaraScanErrors_#{file_timestamp}.txt"))

main_tab.appendCheckBox("tag_matches","Tag Items with Rule Matches",true)
main_tab.appendTextField("match_root_tag","Rule Match Root Tag","Yara")
main_tab.enabledOnlyWhenChecked("match_root_tag","tag_matches")

main_tab.appendCheckBox("cm_match_list","Record Matches as Custom Metadata",true)
main_tab.appendTextField("cm_match_field","Custom Field Name","Yara Matches")
main_tab.enabledOnlyWhenChecked("cm_match_field","cm_match_list")

# Build tab for selecting rules
rules_tab = dialog.addTab("rules_tab","Yara Rules")
rules_tab.appendChoiceTable("rules","Yara Rules",rule_choices)

# Validate user's settings
dialog.validateBeforeClosing do |values|
	# Make sure rules are selected
	if values["rules"].size < 1
		CommonDialogs.showWarning("Please select at least one Yara rule","No Rules Selected")
		next false
	end

	# Make sure we have a temp directory to work with
	if values["temp_directory"].nil? || values["temp_directory"].strip.empty?
		CommonDialogs.showWarning("Please provide a temp directory","No Temp Directory")
		next false
	end

	# Make sure user selected place to save log file
	if values["log_file"].nil? || values["log_file"].strip.empty?
		CommonDialogs.showWarning("Please select a log file save location")
		next false
	end
	
	# Make sure user selected place to save errors log file
	if values["error_log_file"].nil? || values["error_log_file"].strip.empty?
		CommonDialogs.showWarning("Please select an error log file save location")
		next false
	end

	# Make sure user provided root tag name if we are applying tags
	if values["tag_matches"] && values["match_root_tag"].strip.empty?
		CommonDialogs.showWarning("Please provide a root tag name")
		next false
	end

	# Make sure user provided a custom metadata field name if applying custom metadata
	if values["cm_match_list"] && values["cm_match_field"].strip.empty?
		CommonDialogs.showWarning("Please provide a custom metadata field name")
		next false
	end

	# Get user confirmation about closing all workbench tabs
	if CommonDialogs.getConfirmation("The script needs to close all workbench tabs, proceed?") == false
		next false
	end

	next true
end

# Display the settings dialog
dialog.display

# Do the work if everything is ready to go
if dialog.getDialogResult == true
	# Obtain settings as Hash/Map
	values = dialog.toMap

	# Break out values into more convenient variables
	rules = values["rules"]
	yara_wrapper.set_used_rules(rules)
	temp_directory = values["temp_directory"]
	yara_concurrency = values["yara_concurrency"]
	log_file = values["log_file"]
	error_log_file = values["error_log_file"]
	include_descendants = resolved_items_choices[values["resolved_items_choice"]][:include_descendants]
	tag_matches = values["tag_matches"]
	match_root_tag = values["match_root_tag"]
	cm_match_list = values["cm_match_list"]
	cm_match_field = values["cm_match_field"]

	if cm_match_list
		$window.closeAllTabs
	end

	# Create instances of the Logger class
	run_log = Logger.new(log_file)
	error_log = Logger.new(error_log_file)

	# 1. Get items
	# 2. Export each item
	# 3. Run yara rules against exported binary
	# 4. Capture output
	# 5. Record output as tags/custom metadata
	# 6. Record output to report

	# All this will be done with progress dialog displayed
	ProgressDialog.forBlock do |pd|
		pd.setTitle("Yara Integration")
		pd.setAbortButtonVisible(true)

		# When a message is logged to the progress dialogs, also output
		# that message to standard output via puts, this will make sure
		# these messages will also appear in the Nuix logs
		pd.onMessageLogged do |message|
			puts message
		end

		pd.logMessage("Log File: #{log_file}")
		pd.logMessage("Error Log File: #{error_log_file}")

		# Make sure the selected temp directory exists
		j_temp_directory = java.io.File.new(temp_directory)
		if !j_temp_directory.exists
			pd.logMessage("Creating Temp Directory: #{temp_directory}")
			j_temp_directory.mkdirs
		else
			pd.logMessage("Temp Directory: #{temp_directory}")
		end

		# Report the rules we will be using
		pd.logMessage("#{rules.size} Selected Rules:")
		run_log.log("#{rules.size} Selected Rules:")
		rules.each do |rule|
			message = "  #{rule.name}"
			pd.logMessage(message)
			run_log.log(message)
		end

		pd.logMessage("Tag Matches: #{tag_matches}")
		if tag_matches
			pd.logMessage("Match Root Tag: #{match_root_tag}")
		end

		pd.logMessage("Items to Scan: #{values["resolved_items_choice"]}")

		# Obtain the items we will be using
		items = $current_selected_items
		pd.logMessage("Items Selected: #{items.size}")

		# If user selected option to include selection descendants we need
		# to go out and find those now
		if include_descendants
			pd.setMainStatusAndLogIt("Locating Descendant Items...")
			items = $utilities.getItemUtility.findItemsAndDescendants(items)
			pd.logMessage("Items (with descendants): #{items.size}")
		end

		# No point running Yara against anything which doesn't actually have binary to
		# export so lets filter those out now
		pd.setMainStatusAndLogIt("Filtering Out Items Without Binary...")
		items = items.select{|item| item.getBinary.isAvailable}
		pd.logMessage("Items to Process: #{items.size}")

		pd.logMessage("Concurrent Yara Processes: #{yara_concurrency}")

		# Make sure messages logged to progress dialog are preceeded by
		# time stamps
		pd.setTimestampLoggedMessages(true)

		# We will be using a good amount of threading, so we need a way to keep
		# some shared variables safe
		lock = Mutex.new

		# Track progress using these variables so we can report how things are going
		exported = 0
		yara_scanned = 0
		yara_matched = 0
		yara_errors = 0
		annotated = 0

		# Several thread safe queues so that the different threads can
		# share data with each other
		pending_export_queue = Queue.new
		pending_yara_queue = Queue.new
		pending_annotation_queue = Queue.new

		# Load the items into the initial queue
		items.each do |item|
			pending_export_queue << item
		end

		#===============#
		# Export Thread #
		#===============#

		# Build the thread which is responsible for exporting the binary of each item to be scanned
		export_thread = Thread.new {
			# Get API binary exporter
			binary_exporter = $utilities.getBinaryExporter
			# Loop as long as the queue still has items in it
			while pending_export_queue.size > 0
				# Break from loop is user requested abort through the progress dialog
				break if pd.abortWasRequested
				# Pop the next item off the queue
				item = pending_export_queue.pop

				# Get item's guid and build a temporary export file path
				guid = item.getGuid
				export_file = File.join(temp_directory,"#{guid}.#{item.getCorrectedExtension}").gsub("/","\\\\")
				
				#pd.logMessage("Exporting: #{export_file}")
				
				#TODO: At detection of file system stored binary and scan that directly if available

				begin
					# Export the item's binary
					binary_exporter.exportItem(item,export_file)

					# Record the item and the path it was exported to
					data = {
						:item => item,
						:binary_file => export_file,
					}

					# Add this data to the Yara threads' queue
					pending_yara_queue << data

					# Increment count of exported items in a thread safe way
					lock.synchronize{ exported += 1 }
				rescue Exception => exc
					error_message = "Error while exporting item with GUID #{guid}: #{exc.message}"
					# Show we had an error in the progress dialog
					pd.logMessage(error_message)
					# Record the error to the log as well
					error_log.log(error_message)
					error_log.log(exc.backtrace.join("\n"))
				end
			end

			# Once the above while loop exits, we will signal the Yara threads that things have
			# completed by pushing a nil for each Yara thread to consume
			yara_concurrency.times do |i|
				pending_yara_queue << nil
			end
		}


		#==============#
		# Yara Threads #
		#==============#

		# Build the threads which will execute Yara against the binaries.  The number of threads
		# built is determined by the Yara concurrency setting the user selected
		yara_threads = []

		yara_concurrency.times do |i|
			yara_threads << Thread.new {
				data = nil
				# Loop until logic within the loop actually says to stop
				while true
					# Pop next piece of data off the queue
					data = pending_yara_queue.pop

					# If data is nil, this is the export thread signalling there are actually
					# no more items to process so we can break from the loop
					# Also if the user requested to abort from the progress dialog we can break
					# from the loop as well
					break if data.nil? || pd.abortWasRequested
					
					#pd.logMessage("Running yara on: #{data[:binary_file]}")
					
					# Grab the relevant item from the data
					item = data[:item]

					# Parse into listing of matched rules
					output = yara_wrapper.run_rules(data[:binary_file])
					matched_rules = output[:stdout].map{|l|l.split(" ")[0]}
					data[:matched_rules] = matched_rules

					item_binary_file = java.io.File.new(data[:binary_file])

					# If we got hits or errors, we will first generate a blurb with some
					# info about this item, then record our findings leading with this blurb
					if output[:stdout].size > 0 || output[:stderr].size > 0
						item_info = "\n"
						item_info << "Item Path: #{item.getPathNames.join("/")}\n"
						item_info << "GUID: #{item.getGuid}\n"
						item_info << "Kind: #{item.getKind.getName}\n"
						item_info << "Mime Type: #{item.getType.getName}\n"
						item_info << "MD5: #{item.getDigests.getMd5 || "N/A"}\n"
						item_info << "Audited Size: #{item.getAuditedSize}\n"
						item_info << "Exported Binary File Location: #{data[:binary_file]}\n"
						begin
							item_info << "File Exists: #{item_binary_file.exists}\n"
							item_info << "File Size: #{item_binary_file.length}\n"
						rescue Exception => file_exc
							item_info << "Error getting information about exported file: #{file_exc.message}\n"
						end
						item_info << "#{matched_rules.size} Matched Rules:\n"

						# If running Yara yielded matches, record information about the item
						# and the matched rules
						if output[:stdout].size > 0
							lock.synchronize{ yara_matched += 1}
							message = item_info + matched_rules.map{|m| "\t#{m}"}.join("\n")
							run_log.log(message)
						end

						# If Yara reported errors via standard error, record those error messages
						# to the error log
						if output[:stderr].size > 0
							lock.synchronize{ yara_errors += 1 }
							error_message = item_info + output[:stderr].map{|l| "\t#{l}"}.join("\n")
							error_log.log(error_message)
						end
					end

					# Push the results over to the annotation thread's queue
					pending_annotation_queue << data
					
					item_binary_file.delete
					lock.synchronize{ yara_scanned += 1 }
				end
				# Signals that was the last one because data should be nil at this point
				pending_annotation_queue << data
			}
		end

		#===================#
		# Annotation Thread #
		#===================#

		# Build the thread which is responsible for applying annotations to Nuix items based on the
		# findings of Yara scans
		annotation_thread = Thread.new {
			data = nil
			yara_done_count = 0
			# Loop until logic in the loop says to stop
			while true
				# Pop the next piece of data from the queue
				data = pending_annotation_queue.pop
				# Stop logic is a little more complex for this thread.  We count the number of nil's we
				# pop from the queue until the count matches the number of Yara threads.  Basically each
				# yara thread needs to say that is has completed before we break from this loop.
				if data.nil?
					yara_done_count += 1
					if yara_done_count == yara_concurrency
						break
					else
						next
					end
				end
				# Break from the loop if the user requested to abort from the progress dialog
				break if pd.abortWasRequested

				# Take the matched rules and apply them as tags back to the related items
				matched_rules = data[:matched_rules]
				item = data[:item]
				if matched_rules.size > 0
					annotation_applied = false

					# Are we applying tags?
					if tag_matches
						matched_rules.each do |matched_rule|
							item.addTag("#{match_root_tag}|#{matched_rule}")
						end
						annotation_applied = true
					end

					# Are we applying custom metadata?
					if cm_match_list
						cm = item.getCustomMetadata

						# Maintain existing results in this field in case someone runs this
						# script more than once with different rules selected
						existing_value = cm[cm_match_field]
						if !existing_value.nil?
							matched_rules += existing_value.split("; ").reject{|v|v.nil? || v.strip.empty?}
						end

						# Build delimited field value and record that as custom metadata
						match_list_value = matched_rules.uniq.sort.join("; ")
						cm[cm_match_field] = match_list_value
						annotation_applied = true
					end

					# Did we end up applying any annotations?
					if annotation_applied
						lock.synchronize{ annotated += 1 }
					end
				end
			end
		}

		#========================#
		# Progress Update Thread #
		#========================#

		# Build the thread which will periodically update the progress dialog
		progress_thread = Thread.new {
			last_status_update = Time.now
			last_log_update = Time.now
			status_update_frequency = 1
			status_logged_frequency = 5
			while true
				# Periodically update status
				if (Time.now - last_status_update) > status_update_frequency
					lock.synchronize{
						pd.setMainStatus("Exported: #{exported}/#{items.size}, Scanned: #{yara_scanned}, Matched: #{yara_matched}, Annotated: #{annotated},"+
							" Yara Errors: #{yara_errors}")
					}
					last_status_update = Time.now
				end

				# Periodically log the status
				if (Time.now - last_log_update) > status_logged_frequency
					lock.synchronize{
						pd.logMessage("Exported: #{exported}/#{items.size}, Scanned: #{yara_scanned}, Matched: #{yara_matched}, Annotated: #{annotated},"+
							" Yara Errors: #{yara_errors}")
					}
					last_log_update = Time.now
				end
			end
		}

		# Here we join all the threads.  Basically script execution will wait until
		# the annotation thread has determined is has finished up
		export_thread.join
		yara_threads.map{|t| t.join}
		annotation_thread.join

		# Once we reach here, all the other threads should be completed so we
		# can kill the progress thread
		progress_thread.kill

		# Finish up by reporting whether the user aborted and some final counts
		if pd.abortWasRequested
			pd.logMessage("User Aborted!")
			run_log.log("\nUser Aborted!")
		else
			pd.setCompleted
			run_log.log("\nCompleted")
		end

		if tag_matches
			$window.openTab("workbench",{:search=>"tag:\"#{match_root_tag}|*\""})
		else
			$window.openTab("workbench",{:search=>""})
		end

		pd.logMessage("Exported: #{exported}/#{items.size}, Scanned: #{yara_scanned}, Matched: #{yara_matched}, Annotated: #{annotated},"+
			" Yara Errors: #{yara_errors}")

		run_log.log("\n\nMatched Items: #{yara_matched}/#{items.size}")
	end
end