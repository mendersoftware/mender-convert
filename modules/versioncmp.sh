# Copyright 2022 Northern.tech AS
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

source modules/log.sh
source modules/probe.sh

# Compare the version of a string to a given minimum version requirement
#
# NOTE: Also works for 'master', in that sort does sort it correctly by accident.
#       The same goes for all other branches/names, which are not semver.
#
#  $1 - Minimum required version
#  $2 - Version string
#
# @return - bool
#
function minimum_required_version()  {
    if [[ $# -ne 2 ]]; then
        log_fatal "minimum_required_version() requires two parameters"
    fi
    [[ "$1" == "$(printf "$1\n$2" | sort --version-sort | head --lines 1)" ]]
}
