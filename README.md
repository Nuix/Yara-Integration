Yara Integration
================

![Last tested in Nuix 7.4](https://img.shields.io/badge/Nuix-7.4-green.svg)

View the GitHub project [here](https://github.com/Nuix/Yara-Integration) or download the latest release [here](https://github.com/Nuix/Yara-Integration/releases).

# Overview

This script provides integration between [Yara](http://virustotal.github.io/yara/) and [Nuix](https://www.nuix.com/) workbench.  The script allows the user to make a selection of Nuix items in a case, a selection of Yara rules and then run those rules against those items.  Rule matches are recorded as tags on the items in the case as well as in a log file.

# Getting Started

## Setup

Begin by downloading the latest release.  Extract the folder `YaraIntegration.nuixscript` and its contents from the archive into your Nuix scripts directory.  In windows this directory is likely going to be either of the following:

- `%appdata%\Nuix\Scripts` - User level script directory
- `%programdata%\Nuix\Scripts` - System level script directory

Then [download a release of Yara](https://github.com/VirusTotal/yara/releases) and place that in the sub directory named `yara_executable`.

Then place 1 or more Yara rule `.yar` files into the sub directory named `yara_rules`.

## Running the Script

Open a Nuix case in workbench, select 1 or more items in the reuslts view, then run the script from the "Scripts" menu.  The script will display a settings dialog with the following settings:

| Setting | Description |
| ------- | ----------- |
| **Yara Rules** | Select 1 or more Yara rules to be ran against the selected items. |
| **Concurrent Yara Processes** | Determines how many Yara scans the script will attempt to execute concurrently. |
| **Temp Directory** | Determines the location to which the script will temporarily export item binaries for Yara scans. |
| **Log File** | Location to save a log of scan results. |
| **Error Log File** | Location to save a log of errors. |
| **Tag Items with Rule Matches** | Applies a tag denoting matched rules to items. |
| **Rule Match Root Tag** | When applying tags, this is the root tag to use.  Rule based tags will be nested beneath this one. |
| **Record Matches as Custom Metadata** | When checked all matching rules will be listed as a semicolon delimited list in a custom metadata field on the item. |
| **Custom Field Name** | The name of the custom metadata field when applying custom metadata. |

Once configured, click the "Ok" button.  A progress dialog will be displayed as the script exports, scans and report on the Yara scan findings.

## Cloning this Repository

This script relies on code from [Nx](https://github.com/Nuix/Nx) to present a settings dialog and progress dialog.  This JAR file is not included in the repository (although it is included in release downloads).  If you clone this repository, you will also want to obtain a copy of Nx.jar by either:
1. Building it from [the source](https://github.com/Nuix/Nx)
2. Downloading an already built JAR file from the [Nx releases](https://github.com/Nuix/Nx/releases)

Once you have a copy of Nx.jar, make sure to include it in the same directory as the script.

# License

```
Copyright 2018 Nuix

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
