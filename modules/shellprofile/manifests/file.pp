# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
define shellprofile::file($content) {
    include shellprofile::base
    include shellprofile::settings
    include users::root

    file {
	"${::shellprofile::settings::profile_puppet_d}/${title}.sh":
	    owner => $users::root::username,
	    group => $users::root::group,
	    content => "${content}\n";
    }
}
