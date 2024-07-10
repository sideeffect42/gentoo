# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# force ninja, the emake generator errors
CMAKE_MAKEFILE_GENERATOR=ninja
PYTHON_COMPAT=( python3_{6..12} )

inherit desktop cmake python-any-r1 git-r3 ninja-utils

DESCRIPTION="Ladybird is an ongoing project to build a truly independent web browser from scratch."
HOMEPAGE="https://www.ladybird.dev/"
EGIT_REPO_URI="https://github.com/LadybirdWebBrowser/${PN}.git"
LICENSE="BSD-2"
SLOT="0"
#KEYWORDS="~amd64 ~arm64 ~ppc64"

EXTRA_CACERT_VERSION="2023-12-12"
SRC_URI="
	https://curl.se/ca/cacert-${EXTRA_CACERT_VERSION:?}.pem
	https://raw.githubusercontent.com/publicsuffix/list/master/public_suffix_list.dat
"
SKIA_EGIT_REPO_URI="https://skia.googlesource.com/skia.git"
SKIA_VERSION=124
SKIA_EGIT_COMMIT=refs/heads/chrome/m$((SKIA_VERSION))
SKIA_BDEPEND="dev-build/gn"
SKIA_RDEPEND="
	dev-libs/expat
	media-libs/freetype:2
	media-libs/harfbuzz
	media-libs/libwebp
"
# SKIA_RDEPEND already required by ladybird:
#	 dev-libs/icu
#	 media-libs/libjpeg-turbo
#	 media-libs/libpng
#	 sys-libs/zlib

IUSE="+gui pulseaudio skia test"

RESTRICT="!test? ( test )"

# sdl2 for Meta/Lagom/Contrib/VideoPlayerSDL?
RDEPEND="
	dev-libs/icu
	media-libs/woff2
	>=dev-db/sqlite-3
	media-libs/fontconfig
	media-libs/libjpeg-turbo:0=
	media-libs/libpng[apng]
	>=media-libs/libavif-1.0.0
	>=x11-libs/libxkbcommon-0.5.0
	virtual/libcrypt:=
	sys-libs/zlib
	media-libs/libglvnd
	gui? (
		dev-qt/qtbase:6
		dev-qt/qtwidgets:6
		dev-qt/qtnetwork:6
		pulseaudio? ( media-libs/libpulse )
		!pulseaudio? ( dev-qt/qtmultimedia:6 )
	)
	skia? ( ${SKIA_RDEPEND-} )
"
DEPEND="${RDEPEND}"

BDEPEND="
	|| ( >=sys-devel/gcc-13 >=sys-devel/clang-17 )
	virtual/pkgconfig
	>=dev-build/cmake-3.25
	dev-qt/qttools:6
	${PYTHON_DEPS}
	skia? ( ${SKIA_BDEPEND-} )
"

PATCHES=(
	"${FILESDIR}/cmake-fix-rpath.patch"
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

	if use skia
	then
		git-r3_fetch "${SKIA_EGIT_REPO_URI}" "${SKIA_EGIT_COMMIT:-main}"
		git-r3_checkout "${SKIA_EGIT_REPO_URI}" "${WORKDIR}/skia"
	fi
}

src_prepare() {
	cmake_src_prepare

	# patch (out) Skia
	if use skia
	then
		pushd "${WORKDIR}/skia"
		eapply "${FILESDIR}"/skia-*.patch
		popd
	else
		eapply "${FILESDIR}/byebye-skia.patch"
	fi

	if use skia
	then
		# build Skia in prepare stage because it must be present for Ladybird's configure stage to succeed.
		einfo "Compiling Skia..."

		pushd "${WORKDIR}/skia"

		ln -s /usr/bin/gn bin/gn

		local skiagnargs=(
			is_official_build=true
			skia_use_dng_sdk=false
			skia_enable_pdf=false
			skia_use_wuffs=false
			skia_use_system_expat=true
			skia_use_system_freetype2=true
			skia_use_system_harfbuzz=true
			skia_use_system_icu=true
			skia_use_system_libjpeg_turbo=true
			skia_use_system_libpng=true
			skia_use_system_libwebp=true
			skia_use_system_zlib=true
		)
		bin/gn gen out/Static --args="${skiagnargs[*]}"
		eninja -C out/Static

		popd

		# "install" Skia
		mkdir "${WORKDIR}/skia.install"

		pushd "${WORKDIR}/skia.install"

		mkdir -v include
		mkdir -v include/skia
		mv -v "${WORKDIR}"/skia/include/* include/skia/
		mkdir -v include/skia/modules
		local m
		for m in "${WORKDIR}"/skia/modules/*
		do
			mkdir -v "include/skia/modules/${m##*/}"
			find "${m}" -name '*.h' -exec mv -v {} "include/skia/modules/${m##*/}/" \;
		done

		find include -name '*.h' \
			-exec sed -i -e 's/^[ 	]*#include \([<"]\)\(include\/\|src\/\)\(.*\)[">].*/#include \1\3\1/' {} \;
		mkdir -v lib
		mv -v "${WORKDIR}"/skia/out/Static/*.a lib/

		mkdir -v lib/pkgconfig
		cat <<-EOF >lib/pkgconfig/skia.pc
		prefix=${PWD}
		exec_prefix=\${prefix}
		libdir=\${prefix}/lib
		includedir=\${prefix}/include/skia

		Name: skia
		Description: Skia library for ladybird
		Version: $((SKIA_VERSION))
		Libs: -L\${libdir} -l:libskia.a -lexpat -lfreetype -lturbojpeg -lpng16 -lwebpdecoder -lwebpdemux -lz
		Cflags: -I\${includedir}
		EOF

		popd

		einfo "Skia compiled."
	fi
}

src_configure() {
	local mycmakeargs=(
		-DCMAKE_INSTALL_LIBEXECDIR=libexec/Lagom
		-DCMAKE_INSTALL_INCLUDEDIR=include/Lagom
		-DSERENITY_CACHE_DIR="${SERENITY_CACHE_DIR:?}"
		-DHAVE_PULSEAUDIO=$(usex pulseaudio 1 0)
		-DENABLE_NETWORK_DOWNLOADS=off
		-DENABLE_QT=$(usex gui)
		-DBUILD_TESTING=$(usex test)
	)

	if use skia
	then
		export PKG_CONFIG_PATH="${WORKDIR}/skia.install/lib/pkgconfig"
	fi

	cmake_src_configure
}

src_install() {
	cmake_src_install

	# install launcher
	newicon -s 48 -c apps -t hicolor "${S:?}/Base/res/icons/48x48/app-browser.png" ladybird.png
	newicon -s 128 -c apps -t hicolor "${S:?}/Base/res/icons/128x128/app-browser.png" ladybird.png

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
