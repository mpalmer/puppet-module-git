class git::packages {
	noop { "git/packages": }

	case $operatingsystem {
		RedHat,CentOS: {
			$git_packages = "git"
		}
		Debian: {
			# They finally got their shit together for squeeze and got a good name
			case $lsbdistcodename {
				sarge,etch,lenny: {
					$git_packages = [ "git-core", "git-doc" ]
				}
				default: {
					$git_packages = [ "git", "git-doc" ]
				}
			}
		}
	}

	package { $git_packages: before => Noop["git/packages"] }
}
