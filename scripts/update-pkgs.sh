#!/bin/bash

set +e

_SOURCE="${BASH_SOURCE[0]}"
while [ -L "$_SOURCE" ]; do # resolve $_SOURCE until the file is no longer a symlink
  DIR=$( cd -P "$( dirname "${_SOURCE}" )" >/dev/null 2>&1 && pwd )
  _SOURCE=$(readlink "$_SOURCE")
  [[ $_SOURCE != /* ]] && _SOURCE="${DIR}/${_SOURCE}" # if $_SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
PKGS_DIR=$( cd -P "$( dirname "${_SOURCE}" )/../" >/dev/null 2>&1 && pwd )


SRC_REPO="${PKGS_DIR}/src-repos"
AUR_REPO="${PKGS_DIR}/aur-repos"
TEMPLATE_DIR="${PKGS_DIR}/templates"
CONTRIB_DIR="${PKGS_DIR}/contrib"

[ ! -d "${SRC_REPO}" ] && mkdir -p "${SRC_REPO}"
[ ! -d "${AUR_REPO}" ] && mkdir -p "${AUR_REPO}"

_update_repo() {
	PKG_NAME="$1"
	PKG_REPO="$2"

	if [ -z ${PKG_NAME+x} ]; then
		echo "Did not supply package name"
		exit 1
	fi

	if [ -z ${PKG_REPO+x} ]; then
		echo "Did not supply package repo"
		exit 1
	fi

	REPO_DIR="${SRC_REPO}/${PKG_NAME}"

	echo "Updating ${PKG_NAME}"
	pushd "${SRC_REPO}" >/dev/null 2>&1

	[ ! -d "${REPO_DIR}" ] && git clone "${PKG_REPO}" "${PKG_NAME}"

	pushd "${REPO_DIR}" >/dev/null 2>&1
	git fetch --all --prune
	git pull
	popd >/dev/null 2>&1
	popd >/dev/null 2>&1
}

_repo_vesion() {
	PKG_NAME="$1"

	if [ -z ${PKG_NAME+x} ]; then
		echo "Did not supply package name"
		exit 1
	fi


	REPO_DIR="${SRC_REPO}/${PKG_NAME}"
	pushd "${REPO_DIR}" >/dev/null 2>&1
	_GIT_VERSION=$(git describe --tag --always)
	popd >/dev/null 2>&1
	echo "${_GIT_VERSION}"
}

_repo_hash() {
	PKG_NAME="$1"

	if [ -z ${PKG_NAME+x} ]; then
		echo "Did not supply package name"
		exit 1
	fi


	REPO_DIR="${SRC_REPO}/${PKG_NAME}"
	pushd "${REPO_DIR}"  >/dev/null 2>&1
	_GIT_HASH=$(git rev-parse --short HEAD)
	popd  >/dev/null 2>&1
	echo "${_GIT_HASH}"
}

_mk_version() {
	echo "$(TZ=UTC date '+%Y%m%d')_$(echo "$1" | sed 's/-/_/g')"
}


_mk_pkgbuild() {
	PKG_NAME="$1"
	PKG_VER="$2"
	PKG_HASH="$3"

	if [ -z ${PKG_NAME+x} ]; then
		echo "Did not supply package name"
		exit 1
	fi

	if [ -z ${PKG_VER+x} ]; then
		echo "Did not supply package version"
		exit 1
	fi

	if [ -z ${PKG_HASH+x} ]; then
		echo "Did not supply package hash"
		exit 1
	fi

	echo "Making PKGBUILD for ${PKG_NAME}"

	PKG_REPO="${AUR_REPO}/${PKG_NAME}"
	[ ! -d "${PKG_REPO}" ] && mkdir -p "${PKG_REPO}"

	PKGBUILD_IN_FILE="${TEMPLATE_DIR}/${PKG_NAME}-PKGBUILD.in"
	PKGBUILD_FILE="${PKG_REPO}/PKGBUILD"

	sed -e "s/@EDA_VER@/${PKG_VER}/"   \
		-e "s/@EDA_HASH@/${PKG_HASH}/" \
		"${PKGBUILD_IN_FILE}" > "${PKGBUILD_FILE}"

	pushd "${PKG_REPO}" >/dev/null 2>&1
	makepkg --printsrcinfo > .SRCINFO
	cp "${PKGBUILD_IN_FILE}" "PKGBUILD.in"
	cp "${CONTRIB_DIR}/aur.gitignore" ".gitignore"
	popd   >/dev/null 2>&1
}

# specialization for Yosys
_mk_pkgbuild_yosys() {
	PKG_NAME="$1"
	PKG_VER="$2"
	PKG_HASH="$3"

	if [ -z ${PKG_NAME+x} ]; then
		echo "Did not supply package name"
		exit 1
	fi

	if [ -z ${PKG_VER+x} ]; then
		echo "Did not supply package version"
		exit 1
	fi

	if [ -z ${PKG_HASH+x} ]; then
		echo "Did not supply package hash"
		exit 1
	fi

	echo "Making PKGBUILD for ${PKG_NAME}"

	PKG_REPO="${AUR_REPO}/${PKG_NAME}"
	[ ! -d "${PKG_REPO}" ] && mkdir -p "${PKG_REPO}"

	PKGBUILD_IN_FILE="${TEMPLATE_DIR}/${PKG_NAME}-PKGBUILD.in"
	PKGBUILD_FILE="${PKG_REPO}/PKGBUILD"

	YOSYS_CONF="${CONTRIB_DIR}/yosys.conf"
	YOSYS_CONF_HASH="$(sha256sum "${YOSYS_CONF}" | cut -s -d ' ' -f 1)"


	sed -e "s/@EDA_VER@/${PKG_VER}/"            \
		-e "s/@EDA_HASH@/${PKG_HASH}/"          \
		-e "s/@YOSYS_CONF_HASH@/${YOSYS_CONF_HASH}/" \
		"${PKGBUILD_IN_FILE}" > "${PKGBUILD_FILE}"

	pushd "${PKG_REPO}" >/dev/null 2>&1
	makepkg --printsrcinfo > .SRCINFO
	cp "${YOSYS_CONF}" "."
	cp "${PKGBUILD_IN_FILE}" "PKGBUILD.in"
	cp "${CONTRIB_DIR}/aur.gitignore" ".gitignore"
	popd   >/dev/null 2>&1
}


# Specialization for prjoxide and prjtrellis
_mk_pkgbuild_db() {
	PKG_NAME="$1"
	PKG_VER="$2"
	PKG_HASH="$3"
	PKGDB_HASH="$4"

	if [ -z ${PKG_NAME+x} ]; then
		echo "Did not supply package name"
		exit 1
	fi

	if [ -z ${PKG_VER+x} ]; then
		echo "Did not supply package version"
		exit 1
	fi

	if [ -z ${PKG_HASH+x} ]; then
		echo "Did not supply package hash"
		exit 1
	fi

	if [ -z ${PKGDB_HASH+x} ]; then
		echo "Did not supply package db hash"
		exit 1
	fi

	echo "Making PKGBUILD for ${PKG_NAME}"

	PKG_REPO="${AUR_REPO}/${PKG_NAME}"
	[ ! -d "${PKG_REPO}" ] && mkdir -p "${PKG_REPO}"

	PKGBUILD_IN_FILE="${TEMPLATE_DIR}/${PKG_NAME}-PKGBUILD.in"
	PKGBUILD_FILE="${PKG_REPO}/PKGBUILD"

	sed -e "s/@EDA_VER@/${PKG_VER}/"    \
		-e "s/@EDA_HASH@/${PKG_HASH}/"  \
		-e "s/@EDA_DB_HASH@/${PKGDB_HASH}/" \
		"${PKGBUILD_IN_FILE}" > "${PKGBUILD_FILE}"

	pushd "${PKG_REPO}" >/dev/null 2>&1
	makepkg --printsrcinfo > .SRCINFO
	cp "${PKGBUILD_IN_FILE}" "PKGBUILD.in"
	cp "${CONTRIB_DIR}/aur.gitignore" ".gitignore"
	popd   >/dev/null 2>&1
}

_update_aur_repo() {
	PKG_NAME="$1"
	PKG_VER="$2"

	if [ -z ${PKG_NAME+x} ]; then
		echo "Did not supply package name"
		exit 1
	fi

	if [ -z ${PKG_VER+x} ]; then
		echo "Did not supply package version"
		exit 1
	fi

	echo "Updating AUR for ${PKG_NAME}"

	PKG_REPO="${AUR_REPO}/${PKG_NAME}"
	pushd "${PKG_REPO}" >/dev/null 2>&1
	git add PKGBUILD PKGBUILD.in .SRCINFO .gitignore
	git commit -m "Bumpped ${PKG_NAME} version to ${PKG_VER}"
	git push origin master
	popd   >/dev/null 2>&1
	sleep 2
}

# ==== Update Repos ==== #

_update_repo "yosys" "https://github.com/YosysHQ/yosys.git"
_update_repo "sby" "https://github.com/YosysHQ/sby.git"
_update_repo "sby-gui" "https://github.com/YosysHQ/sby-gui.git"
_update_repo "eqy" "https://github.com/YosysHQ/eqy.git"
_update_repo "mcy" "https://github.com/YosysHQ/mcy.git"
_update_repo "scy" "https://github.com/YosysHQ/scy.git"

_update_repo "nextpnr" "https://github.com/YosysHQ/nextpnr.git"

_update_repo "icestorm" "https://github.com/YosysHQ/icestorm.git"

_update_repo "prjtrellis" "https://github.com/YosysHQ/prjtrellis.git"
_update_repo "prjtrellis-db" "https://github.com/YosysHQ/prjtrellis-db.git"

_update_repo "prjoxide" "https://github.com/gatecat/prjoxide.git"
_update_repo "prjoxide-db" "https://github.com/gatecat/prjoxide-db.git"

# _update_repo "prjapicula" "https://github.com/YosysHQ/apicula.git"

# _update_repo "prjmistral" "https://github.com/Ravenslofty/mistral.git"

# ==== Collect Hashes/Versions ==== #

YOSYS_VERSION=$(_repo_vesion "yosys")
YOSYS_HASH=$(_repo_hash "yosys")
YOSYS_PKGVER=$(_mk_version "${YOSYS_VERSION}")

SBY_VERSION=$(_repo_vesion "sby")
SBY_HASH=$(_repo_hash "sby")
SBY_PKGVER=$(_mk_version "${SBY_VERSION}")

SBY_GUI_VERSION=$(_repo_vesion "sby-gui")
SBY_GUI_HASH=$(_repo_hash "sby-gui")
SBY_GUI_PKGVER=$(_mk_version "${SBY_GUI_VERSION}")

EQY_VERSION=$(_repo_vesion "eqy")
EQY_HASH=$(_repo_hash "eqy")
EQY_PKGVER=$(_mk_version "${EQY_VERSION}")

MCY_VERSION=$(_repo_vesion "mcy")
MCY_HASH=$(_repo_hash "mcy")
MCY_PKGVER=$(_mk_version "${MCY_VERSION}")

SCY_VERSION=$(_repo_vesion "scy")
SCY_HASH=$(_repo_hash "scy")
SCY_PKGVER=$(_mk_version "${SCY_VERSION}")

NEXTPNR_VERSION=$(_repo_vesion "nextpnr")
NEXTPNR_HASH=$(_repo_hash "nextpnr")
NEXTPNR_PKGVER=$(_mk_version "${NEXTPNR_VERSION}")

ICESTORM_VERSION=$(_repo_vesion "icestorm")
ICESTORM_HASH=$(_repo_hash "icestorm")
ICESTORM_PKGVER=$(_mk_version "${ICESTORM_VERSION}")

PRJTRELLIS_VERSION=$(_repo_vesion "prjtrellis")
PRJTRELLIS_HASH=$(_repo_hash "prjtrellis")
PRJTRELLIS_DB_VERSION=$(_repo_vesion "prjtrellis-db")
PRJTRELLIS_DB_HASH=$(_repo_hash "prjtrellis-db")
PRJTRELLIS_PKGVER=$(_mk_version "${PRJTRELLIS_VERSION}")

PRJOXIDE_VERSION=$(_repo_vesion "prjoxide")
PRJOXIDE_HASH=$(_repo_hash "prjoxide")
PRJOXIDE_DB_VERSION=$(_repo_vesion "prjoxide-db")
PRJOXIDE_DB_HASH=$(_repo_hash "prjoxide-db")
PRJOXIDE_PKGVER=$(_mk_version "${PRJOXIDE_VERSION}")

# PRJAPICULA_VERSION=$(_repo_vesion "prjapicula")
# PRJAPICULA_HASH=$(_repo_hash "prjapicula")
# PRJAPICULA_PKGVER=$(_mk_version "${PRJAPICULA_VERSION}")

# PRJMISTRAL_VERSION=$(_repo_vesion "prjmistral")
# PRJMISTRAL_HASH=$(_repo_hash "prjmistral")
# PRJMISTRAL_PKGVER=$(_mk_version "${PRJMISTRAL_VERSION}")

echo "Yosys: ${YOSYS_PKGVER} @ ${YOSYS_HASH}"
echo "sby: ${SBY_PKGVER} @ ${SBY_HASH}"
echo "sby: ${SBY_GUI_PKGVER} @ ${SBY_GUI_HASH}"
echo "eqy: ${EQY_PKGVER} @ ${EQY_HASH}"
echo "mcy: ${MCY_PKGVER} @ ${MCY_HASH}"
echo "scy: ${SCY_PKGVER} @ ${SCY_HASH}"
echo "nextpnr: ${NEXTPNR_PKGVER} @ ${NEXTPNR_HASH}"
echo "icestorm: ${ICESTORM_PKGVER} @ ${ICESTORM_HASH}"
echo "prjtrellis: ${PRJTRELLIS_PKGVER} @ ${PRJTRELLIS_HASH}"
echo "prjoxide: ${PRJOXIDE_PKGVER} @ ${PRJOXIDE_HASH}"
# echo "prjapicula: ${PRJAPICULA_PKGVER} @ ${PRJAPICULA_HASH}"
# echo "prjmistral: ${PRJMISTRAL_PKGVER} @ ${PRJMISTRAL_HASH}"


_mk_pkgbuild_yosys "yosys" "${YOSYS_PKGVER}" "${YOSYS_HASH}"
_mk_pkgbuild "sby" "${SBY_PKGVER}" "${SBY_HASH}"
# _mk_pkgbuild "sby-gui" "${SBY_GUI_PKGVER}" "${SBY_GUI_HASH}"
_mk_pkgbuild "eqy" "${EQY_PKGVER}" "${EQY_HASH}"
_mk_pkgbuild "mcy" "${MCY_PKGVER}" "${MCY_HASH}"
# _mk_pkgbuild "scy" "${SCY_PKGVER}" "${SCY_HASH}"

_mk_pkgbuild "icestorm" "${ICESTORM_PKGVER}" "${ICESTORM_HASH}"

_mk_pkgbuild_db "prjtrellis" "${PRJTRELLIS_PKGVER}" "${PRJTRELLIS_HASH}" "${PRJTRELLIS_DB_HASH}"
_mk_pkgbuild_db "prjoxide" "${PRJOXIDE_PKGVER}" "${PRJOXIDE_HASH}"  "${PRJOXIDE_DB_HASH}"
# _mk_pkgbuild "prjapicula" "${PRJAPICULA_PKGVER}" "${PRJAPICULA_HASH}"
# _mk_pkgbuild "prjmistral" "${PRJMISTRAL_PKGVER}" "${PRJMISTRAL_HASH}"


_mk_pkgbuild "nextpnr-generic" "${NEXTPNR_PKGVER}" "${NEXTPNR_HASH}"
_mk_pkgbuild "nextpnr-all" "${NEXTPNR_PKGVER}" "${NEXTPNR_HASH}"
_mk_pkgbuild "nextpnr-ecp5" "${NEXTPNR_PKGVER}" "${NEXTPNR_HASH}"
_mk_pkgbuild "nextpnr-machxo2" "${NEXTPNR_PKGVER}" "${NEXTPNR_HASH}"
_mk_pkgbuild "nextpnr-ice40" "${NEXTPNR_PKGVER}" "${NEXTPNR_HASH}"
_mk_pkgbuild "nextpnr-nexus" "${NEXTPNR_PKGVER}" "${NEXTPNR_HASH}"
# _mk_pkgbuild "nextpnr-gowin" "${NEXTPNR_PKGVER}" "${NEXTPNR_HASH}"
# _mk_pkgbuild "nextpnr-mistral" "${NEXTPNR_PKGVER}" "${NEXTPNR_HASH}"

_update_aur_repo "yosys" "${YOSYS_PKGVER}"
_update_aur_repo "sby" "${SBY_PKGVER}"
_update_aur_repo "eqy" "${EQY_PKGVER}"
_update_aur_repo "mcy" "${MCY_PKGVER}"
_update_aur_repo "icestorm" "${ICESTORM_PKGVER}"
_update_aur_repo "prjtrellis" "${PRJTRELLIS_PKGVER}"
_update_aur_repo "prjoxide" "${PRJOXIDE_PKGVER}"
_update_aur_repo "nextpnr-generic" "${NEXTPNR_PKGVER}"
_update_aur_repo "nextpnr-all" "${NEXTPNR_PKGVER}"
_update_aur_repo "nextpnr-ecp5" "${NEXTPNR_PKGVER}"
_update_aur_repo "nextpnr-machxo2" "${NEXTPNR_PKGVER}"
_update_aur_repo "nextpnr-ice40" "${NEXTPNR_PKGVER}"
_update_aur_repo "nextpnr-nexus" "${NEXTPNR_PKGVER}"
