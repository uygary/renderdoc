#!/bin/bash

FILENAME="$1"
OUTDIR="$2"

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
	echo "Usage: $0 FILENAME [OUTDIR]";
	exit;
fi

if [ -z "$OUTDIR" ]; then
	OUTDIR="${REPO_ROOT}/package"
elif [[ "$OUTDIR" != /* ]] && [[ "$OUTDIR" != [a-zA-Z]:* ]]; then
	OUTDIR="$PWD/$OUTDIR"
fi

if [ ! -d "${REPO_ROOT}"/x64/Release ] && [ ! -d "${REPO_ROOT}"/Win32/Release ] && [ ! -d "${REPO_ROOT}"/ARM64/Release ]; then
	echo "ERROR: Missing Release builds. Build at least one of Win32, x64, or ARM64 first.";
	exit 1;
fi

pushd "${REPO_ROOT}"

# clean any old files lying around and make new structure
rm -rf dist
mkdir -p dist

if [ -d x64/Release ]; then
	mkdir -p dist/Release64
	pushd x64/Release
	find * -not -path 'obj*' -and -not -path '*.lib' -and -not -path 'pymodules*' -exec cp -r --parents '{}' ../../dist/Release64/ \;
	popd
fi

if [ -d Win32/Release ]; then
	mkdir -p dist/Release32
	pushd Win32/Release
	find * -not -path 'obj*' -and -not -path '*.lib' -and -not -path 'pymodules*' -exec cp -r --parents '{}' ../../dist/Release32/ \;
	popd
fi

if [ -d ARM64/Release ]; then
	mkdir -p dist/ReleaseARM64
	pushd ARM64/Release
	find * -not -path 'obj*' -and -not -path '*.lib' -and -not -path 'pymodules*' -exec cp -r --parents '{}' ../../dist/ReleaseARM64/ \;
	popd
fi

# Copy in d3dcompiler from windows kit. Prefer 10 over 8.1 but either works
if [ -f "${WIN_ROOT}c/Program Files (x86)/Windows Kits/10/Redist/D3D/x64/d3dcompiler_47.dll" ]; then
	[ -d dist/Release64 ] && cp "${WIN_ROOT}c/Program Files (x86)/Windows Kits/10/Redist/D3D/x64/d3dcompiler_47.dll" dist/Release64/
	[ -d dist/Release32 ] && cp "${WIN_ROOT}c/Program Files (x86)/Windows Kits/10/Redist/D3D/x86/d3dcompiler_47.dll" dist/Release32/
	[ -d dist/ReleaseARM64 ] && cp "${WIN_ROOT}c/Program Files (x86)/Windows Kits/10/Redist/D3D/arm64/d3dcompiler_47.dll" dist/ReleaseARM64/
elif [ -f "${WIN_ROOT}c/Program Files (x86)/Windows Kits/8.1/Redist/D3D/x64/d3dcompiler_47.dll" ]; then 
	[ -d dist/Release64 ] && cp "${WIN_ROOT}c/Program Files (x86)/Windows Kits/8.1/Redist/D3D/x64/d3dcompiler_47.dll" dist/Release64/
	[ -d dist/Release32 ] && cp "${WIN_ROOT}c/Program Files (x86)/Windows Kits/8.1/Redist/D3D/x86/d3dcompiler_47.dll" dist/Release32/
else
	echo "WARNING: Couldn't find d3dcompiler_47.dll from Windows Kits redist.";
fi

# Copy associated files that should be included with the distribution
for DIR in dist/Release64 dist/Release32 dist/ReleaseARM64; do
	if [ -d "$DIR" ]; then
		cp LICENSE.md "$DIR"/
		cp Documentation/htmlhelp/*.chm "$DIR"/ 2>/dev/null || true
	fi
done

# Copy in appropriate plugins folder if they exist
if [ -d dist/Release64 ]; then
	if [ -d plugins-win64 ]; then
		cp -R plugins-win64/ dist/Release64/plugins
	else
		echo "WARNING: x64 plugins missing, download and extract https://renderdoc.org/plugins.zip in root";
		if [[ "$STRICT" == "yes" ]]; then exit 1; fi
	fi
fi

if [ -d dist/Release32 ]; then
	if [ -d plugins-win32 ]; then
		cp -R plugins-win32/ dist/Release32/plugins
	else
		echo "WARNING: x86 plugins missing, download and extract https://renderdoc.org/plugins.zip in root";
		if [[ "$STRICT" == "yes" ]]; then exit 1; fi
	fi
fi

if [ -d dist/ReleaseARM64 ]; then
	if [ -d plugins-arm64 ]; then
		cp -R plugins-arm64/ dist/ReleaseARM64/plugins
	else
		echo "WARNING: arm64 plugins missing. Ignoring for now since arm64 is new."
	fi
fi

# Delete new VS2015 incremental pdb files, these are just build artifacts
find dist/Release{32,64,ARM64}/ -iname '*.ipdb' -exec rm '{}' \; 2>/dev/null || true
find dist/Release{32,64,ARM64}/ -iname '*.iobj' -exec rm '{}' \; 2>/dev/null || true

# Copy in any android APKs that were built
if [ -d dist/Release64 ]; then
	mkdir -p dist/Release64/plugins/android/
	if ls build-android-* > /dev/null 2>&1; then
		find build-android-* -iname 'org.renderdoc.renderdoccmd.*.apk' -exec cp '{}' dist/Release64/plugins/android ';'
	else
		echo "WARNING: No android builds found, expected build-android-arm32 and build-android-arm64";
		if [[ "$STRICT" == "yes" ]]; then exit 1; fi
	fi

	# Copy in android adb and patching requirements
	if [ -f plugins-android/adb.exe ]; then
		cp -R plugins-android/* dist/Release64/plugins/android/;
	else
		echo "WARNING: Couldn't find android dependency (adb.exe and friends)";
		if [[ "$STRICT" == "yes" ]]; then exit 1; fi
	fi
fi

[ -d dist/Release64/plugins/android ] && [ -d dist/Release32 ] && cp -R dist/Release64/plugins/android dist/Release32/plugins/
[ -d dist/Release64/plugins/android ] && [ -d dist/ReleaseARM64 ] && cp -R dist/Release64/plugins/android dist/ReleaseARM64/plugins/

# Make a copy of the main distribution folder that has PDBs
[ -d dist/Release64 ] && cp -R dist/Release64 dist/ReleasePDBs64
[ -d dist/Release32 ] && cp -R dist/Release32 dist/ReleasePDBs32
[ -d dist/ReleaseARM64 ] && cp -R dist/ReleaseARM64 dist/ReleasePDBsARM64

# Remove all pdbs
find dist/Release{32,64,ARM64}/ -iname '*.pdb' -exec rm '{}' \; 2>/dev/null || true

# Remove any build associated files that might have gotten dumped in the folders
rm -f dist/Release{32,64,ARM64}/*.{exp,lib,metagen,xml} dist/Release{32,64,ARM64}/*.vshost.* 2>/dev/null || true

# Delete all but xml files from PDB folder as well (large files, and not useful)
rm -f dist/ReleasePDBs{32,64,ARM64}/*.{exp,lib,metagen} dist/ReleasePDBs{32,64,ARM64}/*.vshost.* 2>/dev/null || true

# In the 64bit release folder, make an x86 subfolder and copy in renderdoc 32bit
if [ -d dist/Release64 ] && [ -d dist/Release32 ]; then
	mkdir -p dist/Release64/x86
	cp -R dist/Release32/{d3dcompiler_47.dll,renderdoc.dll,renderdoc.json,renderdocshim32.dll,renderdoccmd.exe,dbghelp.dll,symsrv.dll,symsrv.yes} dist/Release64/x86/ 2>/dev/null || true
	mkdir -p dist/ReleasePDBs64/x86
	cp -R dist/ReleasePDBs32/{d3dcompiler_47.dll,renderdoc.dll,renderdoc.json,renderdoc.pdb,renderdocshim32.dll,renderdocshim32.pdb,renderdoccmd.exe,renderdoccmd.pdb,dbghelp.dll,symsrv.dll,symsrv.yes} dist/ReleasePDBs64/x86/ 2>/dev/null || true
fi

# Do the same for ARM64 if Win32 exists
if [ -d dist/ReleaseARM64 ] && [ -d dist/Release32 ]; then
	mkdir -p dist/ReleaseARM64/x86
	cp -R dist/Release32/{d3dcompiler_47.dll,renderdoc.dll,renderdoc.json,renderdocshim32.dll,renderdoccmd.exe,dbghelp.dll,symsrv.dll,symsrv.yes} dist/ReleaseARM64/x86/ 2>/dev/null || true
	mkdir -p dist/ReleasePDBsARM64/x86
	cp -R dist/ReleasePDBs32/{d3dcompiler_47.dll,renderdoc.dll,renderdoc.json,renderdoc.pdb,renderdocshim32.dll,renderdocshim32.pdb,renderdoccmd.exe,renderdoccmd.pdb,dbghelp.dll,symsrv.dll,symsrv.yes} dist/ReleasePDBsARM64/x86/ 2>/dev/null || true
fi

VERSION=`grep -E "#define RENDERDOC_VERSION_(MAJOR|MINOR)" renderdoc/api/replay/version.h | tr -dc '[0-9\n]' | tr '\n' '.' | grep -Eo '[0-9]+\.[0-9]+'`

export RENDERDOC_VERSION="${VERSION}"

# Ensure this variable passes through to windows on WSL
export WSLENV=$WSLENV:RENDERDOC_VERSION

if [ -d dist/Release32 ]; then
	"$WIX/bin/candle.exe" -o dist/Installer32.wixobj util/installer/Installer32.wxs 2>/dev/null || true
	"$WIX/bin/light.exe" -ext WixUIExtension -sw1076 -loc util/installer/customtext.wxl -o dist/Installer32.msi dist/Installer32.wixobj 2>/dev/null || true
	if [[ "$STRICT" == "yes" ]] && [ ! -f dist/Installer32.msi ]; then
		echo "Failed to build 32-bit installer."
		exit 1
	fi
fi

if [ -d dist/Release64 ]; then
	"$WIX/bin/candle.exe" -o dist/Installer64.wixobj util/installer/Installer64.wxs 2>/dev/null || true
	"$WIX/bin/light.exe" -ext WixUIExtension -sw1076 -loc util/installer/customtext.wxl -o dist/Installer64.msi dist/Installer64.wixobj 2>/dev/null || true
	if [[ "$STRICT" == "yes" ]] && [ ! -f dist/Installer64.msi ]; then
		echo "Failed to build 64-bit installer."
		exit 1
	fi
fi

rm -f dist/*.wixobj dist/*.wixpdb

popd # $REPO_ROOT

rm -rf "${OUTDIR}"
mkdir -p "${OUTDIR}"
pushd "${OUTDIR}"

if [ -d "${REPO_ROOT}"/dist/Release32 ]; then
	cp -R "${REPO_ROOT}"/dist/Release32 ${FILENAME}_32
	zip -r ${FILENAME}_32.zip ${FILENAME}_32/
	gpg -o ${FILENAME}_32.zip.sig --detach-sign --armor ${FILENAME}_32.zip 2>/dev/null || true
	if [ -f "${REPO_ROOT}"/dist/Installer32.msi ]; then
		cp "${REPO_ROOT}"/dist/Installer32.msi ${FILENAME}_32.msi
		"${BUILD_ROOT}"/scripts/sign.sh ${FILENAME}_32.msi 2>/dev/null || true
		gpg -o ${FILENAME}_32.msi.sig --detach-sign --armor ${FILENAME}_32.msi 2>/dev/null || true
	fi
	rm -rf ${FILENAME}_32/
fi

if [ -d "${REPO_ROOT}"/dist/Release64 ]; then
	cp -R "${REPO_ROOT}"/dist/Release64 ${FILENAME}_64
	zip -r ${FILENAME}_64.zip ${FILENAME}_64/
	gpg -o ${FILENAME}_64.zip.sig --detach-sign --armor ${FILENAME}_64.zip 2>/dev/null || true
	if [ -f "${REPO_ROOT}"/dist/Installer64.msi ]; then
		cp "${REPO_ROOT}"/dist/Installer64.msi ${FILENAME}_64.msi
		"${BUILD_ROOT}"/scripts/sign.sh ${FILENAME}_64.msi 2>/dev/null || true
		gpg -o ${FILENAME}_64.msi.sig --detach-sign --armor ${FILENAME}_64.msi 2>/dev/null || true
	fi
	rm -rf ${FILENAME}_64/
fi

if [ -d "${REPO_ROOT}"/dist/ReleaseARM64 ]; then
	cp -R "${REPO_ROOT}"/dist/ReleaseARM64 ${FILENAME}_arm64
	zip -r ${FILENAME}_arm64.zip ${FILENAME}_arm64/
	gpg -o ${FILENAME}_arm64.zip.sig --detach-sign --armor ${FILENAME}_arm64.zip 2>/dev/null || true
	rm -rf ${FILENAME}_arm64/
fi

popd # OUTDIR
