# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# force ninja, the emake generator errors
CMAKE_MAKEFILE_GENERATOR=ninja
inherit cmake

PYTHON_COMPAT=( python3_{6..12} )
inherit python-any-r1

inherit git-r3
EGIT_REPO_URI="https://github.com/LadybirdWebBrowser/${PN}.git"
EGIT_COMMIT="25c43554069f21596103b09932cbc51690a05b8a"  # newer commits require skia

EXTRA_CACERT_VERSION="2023-12-12"
EXTRA_TZDB_VERSION="2024a"
EXTRA_UCD_VERSION="15.1.0"

SRC_URI="
	https://curl.se/ca/cacert-${EXTRA_CACERT_VERSION:?}.pem
	https://www.unicode.org/Public/${EXTRA_UCD_VERSION:?}/ucd/UCD.zip -> UCD-${EXTRA_UCD_VERSION:?}.zip
	https://www.unicode.org/Public/emoji/${EXTRA_UCD_VERSION%.0}/emoji-test.txt -> emoji-test-${EXTRA_UCD_VERSION:?}.txt
	https://www.unicode.org/Public/idna/${EXTRA_UCD_VERSION:?}/IdnaMappingTable.txt -> IdnaMappingTable-${EXTRA_UCD_VERSION:?}.txt
	https://raw.githubusercontent.com/publicsuffix/list/master/public_suffix_list.dat
	https://data.iana.org/time-zones/releases/tzdata${EXTRA_TZDB_VERSION:?}.tar.gz
"

DESCRIPTION="Ladybird is an ongoing project to build a truly independent web browser from scratch."
HOMEPAGE="https://www.ladybird.dev/"
LICENSE="BSD-2"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

IUSE="+gui test"

RESTRICT="!test? ( test )"

# sdl2 for Meta/Lagom/Contrib/VideoPlayerSDL?
RDEPEND="
	dev-libs/icu
	media-libs/woff2
	>=dev-db/sqlite-3
	media-libs/fontconfig
	media-libs/libjpeg-turbo:0=
	x11-libs/libxkbcommon
	virtual/libcrypt:=
	gui? (
		dev-qt/qtbase:6
		dev-qt/qtwidgets:6
		dev-qt/qtnetwork:6
		|| (
			dev-qt/qtmultimedia:6
			media-libs/libpulse
		)
	)
"
DEPEND="${RDEPEND}"

BDEPEND="
	>=dev-build/cmake-3.25
	dev-qt/qttools:6
	${PYTHON_DEPS}
"

PATCHES=(
	"${FILESDIR:?}/ByteBuffer-overflow.patch"
	"${FILESDIR:?}/ARMv8-CRC32.patch"
)

SERENITY_CACHE_DIR="${WORKDIR}/caches"

src_unpack() {
	git-r3_src_unpack

	mkdir "${SERENITY_CACHE_DIR:?}" || die

	# install additional distfiles

	mkdir "${SERENITY_CACHE_DIR:?}/CACERT" || die
	printf '%s' "${EXTRA_CACERT_VERSION:?}" >"${SERENITY_CACHE_DIR:?}/CACERT/version.txt" || die
	cp -v "${DISTDIR:?}/cacert-${EXTRA_CACERT_VERSION:?}.pem" "${SERENITY_CACHE_DIR:?}/CACERT/cacert-${EXTRA_CACERT_VERSION:?}.pem" || die

	mkdir "${SERENITY_CACHE_DIR:?}/UCD" || die
	printf '%s' "${EXTRA_UCD_VERSION:?}" >"${SERENITY_CACHE_DIR:?}/UCD/version.txt" || die
	(cd "${SERENITY_CACHE_DIR:?}/UCD" && unpack "UCD-${EXTRA_UCD_VERSION:?}.zip") || die
	cp -v "${DISTDIR:?}/emoji-test-${EXTRA_UCD_VERSION:?}.txt" "${SERENITY_CACHE_DIR:?}/UCD/emoji-test.txt" || die
	cp -v "${DISTDIR:?}/IdnaMappingTable-${EXTRA_UCD_VERSION:?}.txt" "${SERENITY_CACHE_DIR:?}/UCD/IdnaMappingTable.txt" || die

	mkdir "${SERENITY_CACHE_DIR:?}/TZDB" || die
	printf '%s' "${EXTRA_TZDB_VERSION:?}" >"${SERENITY_CACHE_DIR:?}/TZDB/version.txt" || die
	(cd "${SERENITY_CACHE_DIR:?}/TZDB" && unpack "tzdata${EXTRA_TZDB_VERSION:?}.tar.gz") || die

	mkdir "${SERENITY_CACHE_DIR:?}/PublicSuffix" || die
	cp -v "${DISTDIR:?}/public_suffix_list.dat" "${SERENITY_CACHE_DIR:?}/PublicSuffix/public_suffix_list.dat" || die
}

src_configure() {
	local mycmakeargs=(
		-DSERENITY_CACHE_DIR="${SERENITY_CACHE_DIR:?}"
		-DENABLE_NETWORK_DOWNLOADS=off
		-DENABLE_QT=$(usex gui)
	)

	cmake_src_configure
}
