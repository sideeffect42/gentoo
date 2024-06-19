# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CMAKE_MAKEFILE_GENERATOR=ninja
inherit cmake

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

IUSE="+qt6 test"

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
	qt6? (
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
	>=dev-lang/python-3.6
"

PATCHES=(
	"${FILESDIR}/ByteBuffer-overflow.patch"
)

SERENITY_CACHE_DIR="${WORKDIR}/caches"

src_unpack() {
	git-r3_src_unpack

	mkdir "${SERENITY_CACHE_DIR:?}"

	# install additional distfiles

	mkdir "${SERENITY_CACHE_DIR:?}/CACERT"
	printf '%s' "${EXTRA_CACERT_VERSION:?}" >"${SERENITY_CACHE_DIR:?}/CACERT/version.txt"
	cp -v "${DISTDIR:?}/cacert-${EXTRA_CACERT_VERSION:?}.pem" "${SERENITY_CACHE_DIR:?}/CACERT/cacert-${EXTRA_CACERT_VERSION:?}.pem"

	mkdir "${SERENITY_CACHE_DIR:?}/UCD"
	printf '%s' "${EXTRA_UCD_VERSION:?}" >"${SERENITY_CACHE_DIR:?}/UCD/version.txt"
	(cd "${SERENITY_CACHE_DIR:?}/UCD" && unpack "UCD-${EXTRA_UCD_VERSION:?}.zip")
	cp -v "${DISTDIR:?}/emoji-test-${EXTRA_UCD_VERSION:?}.txt" "${SERENITY_CACHE_DIR:?}/UCD/emoji-test.txt"
	cp -v "${DISTDIR:?}/IdnaMappingTable-${EXTRA_UCD_VERSION:?}.txt" "${SERENITY_CACHE_DIR:?}/UCD/IdnaMappingTable.txt"

	mkdir "${SERENITY_CACHE_DIR:?}/TZDB"
	printf '%s' "${EXTRA_TZDB_VERSION:?}" >"${SERENITY_CACHE_DIR:?}/TZDB/version.txt"
	(cd "${SERENITY_CACHE_DIR:?}/TZDB" && unpack "tzdata${EXTRA_TZDB_VERSION:?}.tar.gz")

	mkdir "${SERENITY_CACHE_DIR:?}/PublicSuffix"
	cp -v "${DISTDIR:?}/public_suffix_list.dat" "${SERENITY_CACHE_DIR:?}/PublicSuffix/public_suffix_list.dat"
}

src_configure() {
	local mycmakeargs=(
		-DSERENITY_CACHE_DIR="${SERENITY_CACHE_DIR:?}"
		-DENABLE_NETWORK_DOWNLOADS=off
		-DENABLE_QT=$(usex qt6)
	)

	cmake_src_configure
}
