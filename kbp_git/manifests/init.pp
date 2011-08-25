# Author: Kumina bv <support@kumina.nl>

# Class: kbp_git
#
# Actions:
#	Undocumented
#
# Depends:
#	Undocumented
#	gen_puppet
#
class kbp_git {
	include gen_git
}

# Define: kbp_git::repo
#
# Actions:
#	Set up git repository
#
# Parameters:
#	name
#		The directory where to create the repository.
#		Needs to be a kfile already.
#	branch
#		The remote branch of the origin. Defaults to
#		"master".
#	origin
#		Add an origin to the repository. This does
#		not clone the remote repository.
#
# Depends:
#	kbp_git
#	kbp_git::repo
#	gen_puppet
#
define kbp_git::repo ($branch = "master", $origin = false, $bare = false) {
	include kbp_git

	gen_git::repo { $name:
		branch => $branch,
		origin => $origin,
		bare   => $bare;
	}
}
