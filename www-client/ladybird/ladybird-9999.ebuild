# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop

# force ninja, the emake generator errors
CMAKE_MAKEFILE_GENERATOR=ninja
inherit cmake

PYTHON_COMPAT=( python3_{6..12} )
inherit python-any-r1

inherit git-r3
EGIT_REPO_URI="https://github.com/LadybirdWebBrowser/${PN}.git"

EXTRA_CACERT_VERSION="2023-12-12"

SRC_URI="
	https://curl.se/ca/cacert-${EXTRA_CACERT_VERSION:?}.pem
	https://raw.githubusercontent.com/publicsuffix/list/master/public_suffix_list.dat
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
	|| ( >=sys-devel/gcc-12 >=sys-devel/clang-17 )
	dev-libs/icu
	media-libs/woff2
	>=dev-db/sqlite-3
	media-libs/fontconfig
	media-libs/libjpeg-turbo:0=
	>=x11-libs/libxkbcommon-0.5.0
	virtual/libcrypt:=
	media-libs/libpng[apng]
	sys-libs/zlib
	media-libs/libglvnd
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
	virtual/pkgconfig
	>=dev-build/cmake-3.25
	dev-qt/qttools:6
	${PYTHON_DEPS}
"

PATCHES=(
	"${FILESDIR:?}/ByteBuffer-overflow.patch"
	"${FILESDIR:?}/ARMv8-CRC32.patch"
	"${FILESDIR:?}/ppc64.patch"
	"${FILESDIR:?}/big-endian.patch"
	"${FILESDIR:?}/no-install-testfiles.patch"
	"${FILESDIR:?}/no-install-generators.patch"
	# couldn't figure out how to build this trash fire
	"${FILESDIR:?}/byebye-skia.patch"
)

SERENITY_CACHE_DIR="${WORKDIR}/caches"

src_unpack() {
	git-r3_src_unpack

	mkdir "${SERENITY_CACHE_DIR:?}" || die

	# install additional distfiles

	mkdir "${SERENITY_CACHE_DIR:?}/CACERT" || die
	printf '%s' "${EXTRA_CACERT_VERSION:?}" >"${SERENITY_CACHE_DIR:?}/CACERT/version.txt" || die
	cp -v "${DISTDIR:?}/cacert-${EXTRA_CACERT_VERSION:?}.pem" "${SERENITY_CACHE_DIR:?}/CACERT/cacert-${EXTRA_CACERT_VERSION:?}.pem" || die

	mkdir "${SERENITY_CACHE_DIR:?}/PublicSuffix" || die
	cp -v "${DISTDIR:?}/public_suffix_list.dat" "${SERENITY_CACHE_DIR:?}/PublicSuffix/public_suffix_list.dat" || die
}

src_configure() {
	local mycmakeargs=(
		-DCMAKE_INSTALL_LIBEXECDIR=libexec/Lagom
		-DCMAKE_INSTALL_INCLUDEDIR=include/Lagom
		-DSERENITY_CACHE_DIR="${SERENITY_CACHE_DIR:?}"
		-DENABLE_NETWORK_DOWNLOADS=off
		-DENABLE_QT=$(usex gui)
		-DBUILD_TESTING=$(usex test)
	)

	cmake_src_configure
}

src_install() {
	cmake_src_install

	# install launcher
	for s in 16 32
	do
		newicon -s $((s)) -c apps -t hicolor "${S:?}/Base/res/icons/$((s))x$((s))/app-browser.png" ladybird.png
	done

	domenu "${FILESDIR:?}/${PN}.desktop"
}

pkg_postinst() {
	xdg_icon_cache_update
	xdg_desktop_database_update
}

pkg_postrm() {
	xdg_icon_cache_update
	xdg_desktop_database_update
}
