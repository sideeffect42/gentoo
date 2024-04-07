# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools

DESCRIPTION="W3C Embeddable OpenType font (EOT) creation tools"
HOMEPAGE="http://www.w3.org/Tools/eot-utils/"
SRC_URI="http://www.w3.org/Tools/eot-utils/eot-utilities-${PV}.tar.gz"

S="${WORKDIR}/eot-utilities-${PV}"

# License of the package.  This must match the name of file(s) in the
# licenses/ directory.  For complex license combination see the developer
# docs on gentoo.org for details.
LICENSE="W3C"

SLOT="0"
KEYWORDS="arm64"
IUSE=""

src_prepare() {
	default
	eautoreconf
}
