# Make a checkout of a git repo.
#
# Noops:
#
#  * `git/checkout/preclone:${name}`
#
#     This noop is guaranteed to complete before the clone of
#     the repo is performed.  So, anything you want to happen before the clone
#     should happen before this noop.
#
#  * `git/checkout/clone:${name}`
#
#     This noop will be notified after the initial clone is complete.  it
#     will not be notified ever again, but you can require on it if you just
#     want to make sure the clone has completed successfully before
#     evaluating some other resource.
#
#  * `git/checkout/update:${name}`
#
#     This will be notified when an update occurs.
#
# Attributes:
#
#  * `url` (string; required)
#
#     A URL which git will understand, from which the repository will be
#     cloned (and subsequently kept up-to-date).  Changing this after the
#     repo has been cloned is supported.
#
#  * `target` (string; required)
#
#     Where the checkout will be made to.  Changing this will cause the
#     clone to be remade and the old location will hang around, so remember
#     to clean up after yourself if necessary.
#
#  * `ref` (string; optional; default `master`)
#
#     The `tree-ish` which will be checked out.  This can be a branch, a
#     tag, a hash, or anything else that git will understand.
#
#  * `user` (string; optional; default `root`)
#
#     The user who will own all of the files in the checkout.
#
#  * `group` (string; optional; default `root`)
#
#     The group which will own all of the files in the checkout.
#
#  * `update` (boolean; optional; default `false`)
#
#     Whether or not to ensure that the repo is at the most up-to-date
#     `tree-ish` every time Puppet runs.
#
define git::checkout(
		$url,
		$target,
		$ref    = "master",
		$user   = "root",
		$group  = "root",
		$update = false
) {
	noop {
		"git/checkout/preclone:${name}": ;
		"git/checkout/clone:${name}":
			require => Noop["git/checkout/preclone:${name}"];
		"git/checkout/update:${name}":
			require => Noop["git/checkout/clone:${name}"];
	}

	include git::packages

	Exec { path => "/usr/local/bin:/usr/bin:/bin" }

	$sq_url    = shellquote($url)
	$sq_target = shellquote($target)
	$sq_ref    = shellquote($ref)

	exec {
		"Clone ${url} to ${target}":
			command     => "git clone ${sq_url} ${sq_target}",
			creates     => "${target}/.git",
			user        => $user,
			group       => $group,
			notify      => Noop["git/checkout/clone:${name}"],
			require     => [ Noop["git/packages"],
			                 Noop["git/checkout/preclone:${name}"]
			               ];
		"Checkout ${url}:${ref} at ${target}":
			command     => "git checkout ${sq_ref}",
			cwd         => $target,
			user        => $user,
			group       => $group,
			refreshonly => true,
			subscribe   => Noop["git/checkout/clone:${name}"],
			notify      => Noop["git/checkout/update:${name}"];
	}

	if $update {
		exec {
			"Fetch updates to ${url}:${ref} for ${target}":
				command     => "git fetch origin",
				cwd         => $target,
				user        => $user,
				group       => $group,
				require     => Noop["git/checkout/clone:${name}"];
			# This is a weird resource; the real work is done in the `onlyif`,
			# the command is only there because we need *something* to do if
			# the onlyif fires, apart from notifying the checkout resource
			# that it needs to Do Things
			"Check to see if we need to update ${url}:${ref} at ${target}":
				command     => "/bin/true",
				cwd         => $target,
				user        => $user,
				group       => $group,
				onlyif      => "test \$(git log HEAD..origin/${sq_ref} | wc -l) = 0",
				require     => Exec["Fetch updates to ${url}:${ref} for ${target}"],
				notify      => Exec["Checkout ${url}:${ref} at ${target}"];
		}
	}
}
