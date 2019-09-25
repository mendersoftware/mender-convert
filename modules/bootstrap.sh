#!/usr/bin/env bash
#
# Copyright 2019 Northern.tech AS
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# Credit to:
#    https://github.com/gruntwork-io/bash-commons/blob/master/modules/bash-commons/src/bootstrap.sh

# Sets some Bash options to encourage well formed code.
# For example, some of the options here will cause the script to terminate as
# soon as a command fails. Another option will cause an error if an undefined
# variable is used.
# See: https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html

# Any trap on ERR is inherited by shell functions, command substitutions, and
# commands executed in a subshell environment. The ERR trap is normally not
# inherited in such cases.
set -o errtrace

# Any trap on DEBUG and RETURN are inherited by shell functions, command
# substitutions, and commands executed in a subshell environment. The DEBUG and
# RETURN traps are normally not inherited in such cases.
set -o functrace

# Exit if any command exits with a non-zero exit status.
set -o errexit

# Exit if script uses undefined variables.
set -o nounset

# Prevent masking an error in a pipeline.
# Look at the end of the 'Use set -e' section for an excellent explanation.
# see: https://www.davidpashley.com/articles/writing-robust-shell-scripts/
set -o pipefail

# Make debugging easier when you use `set -x`
# See: http://wiki.bash-hackers.org/scripting/debuggingtips#making_xtrace_more_useful
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

source modules/log.sh
source modules/run.sh
