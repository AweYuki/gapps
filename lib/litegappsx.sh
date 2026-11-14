#################################################
# lib/litegappsx.sh
#
# LiteGappsX product: restore / make / clean.
# Sourced by build.sh (shared helpers + globals, see lib/litegapps.sh header).
#
# Copyright 2020 - 2025 The LiteGapps Project
#################################################

# per-variant config reader (BASED is set by the caller loop)
read_config(){ getp "$1" "$BASED/config"; }

#################################################
# Build one flashable zip for the current $BASED variant
#################################################
make_flashable_litegappsx(){
		tmp77=$tmp
		cdir $tmp77
		printlog "- Build flashable"
		for YR in arm64; do
			copy_binary_flashable $YR $tmp77/bin/$YR
		done
			# copy installer payload (kopi installer)
			for W in 27-litegapps.sh litegapps-post-fs litegapps; do
				if [ -f $utils/$W ]; then
					cp -pf $utils/$W $tmp77/bin/
				else
					ERROR "utils <$utils/$W> not found"
				fi
			done
			# LICENSE
			if [ -f $utils/LICENSE ]; then
				cp -pf $utils/LICENSE $tmp77/
			else
				ERROR "LICENSE <$utils/LICENSE> not found"
			fi

			cp -af $utils/kopi/* $tmp77/

		# action.sh
			if [ -f $utils/action.sh ]; then
				cp -pf $utils/action.sh $tmp77/
			else
				ERROR "action.sh <$utils/action.sh> not found"
			fi
		# Customize.sh
			if [ -f $utils/customize.sh ]; then
				cp -pf $utils/customize.sh $tmp77/
			else
				ERROR "Customize.sh <$utils/customize.sh> not found"
			fi
		# copy file.tar.(type archive) in tmp
		cdir $tmp77/files
		if [ $(get_config litegapps.tar) = "multi" ] && [ -f $tmpfiles/files.tar.$(get_config compression) ]; then
		cp -pf $tmpfiles/files.tar.$(get_config compression) $tmp77/files/
		else
		cp -pf $tmp/files.tar.$(get_config compression) $tmp77/files/
		rm -rf $tmp/files.tar.$(get_config compression)
		fi

		# add modules files
		if [ $(read_config modules) = true ]; then
			test ! -d $tmp77/modules && cdir $tmp77/modules
			if [ -d $BASED/modules/$W_ARCH/$W_SDK ]; then
				cp -af $BASED/modules/$W_ARCH/$W_SDK/* $tmp77/modules/
			else
				printlog "[ERROR] <$BASED/modules/$W_ARCH/$W_SDK> not found"
				sleep 3s
				return 1
			fi
		else
			print "# Modules is disable"
		fi

		local MODULE_PROP=$tmp77/module.prop
		local MODULE_DESC=`read_config desc`
		local MODULE_UPDATE=https://raw.githubusercontent.com/litegapps/updater/main/core/litegappsx/$(read_config dir_name)/update.json
		SED "$(getp litegapps_type $MODULE_PROP)" "litegappsx" $MODULE_PROP
		SED "$(getp name $MODULE_PROP)" "$NAME $PROP_STATUS" $MODULE_PROP
		SED "$(getp id $MODULE_PROP)" "litegapps" $MODULE_PROP
		SED "$(getp author $MODULE_PROP)" "$PROP_BUILDER" $MODULE_PROP
		SED "$(getp version $MODULE_PROP)" "v${PROP_VERSION}" $MODULE_PROP
		SED "$(getp versionCode $MODULE_PROP)" "$PROP_VERSIONCODE" $MODULE_PROP
		SED "$(getp date $MODULE_PROP)" "$(date +%d-%m-%Y)" $MODULE_PROP
		SED "$(getp description $MODULE_PROP)" "$MODULE_DESC" $MODULE_PROP
		SED "$(getp litegapps_variant $MODULE_PROP)" "$VARIANT" $MODULE_PROP
		sed -i 's,'"$(getp updateJson $MODULE_PROP)"','"${MODULE_UPDATE}"',g' $MODULE_PROP

		#set time stamp
		set_time_stamp $tmp77

		local NAME_ZIP="$(read_config name | sed "s/ /-/g")-v${PROP_VERSION}-${PROP_STATUS}.zip"
		local OUT_ZIP=$out/litegappsx/$(read_config dir_name)/v${PROP_VERSION}/$NAME_ZIP
		make_zip $tmp77 $OUT_ZIP
	}

#################################################
# Build the current $VARIANT / $BASED
#################################################
_litegappsx_build_variant(){
	NAME=`read_config name`
	BIN_ARCH=arm64
	sedlog "Building $NAME"
	printmid "Building $NAME"
	printlog " "
	printlog "Version : $PROP_VERSION (${PROP_VERSIONCODE})"
	printlog "Builder : $PROP_BUILDER"
	printlog "Status  : $PROP_STATUS"
	printlog "Compressions : $PROP_COMPRESSION"
	printlog "Compressions Level : $PROP_COMPRESSION_LEVEL"
	printlog " "
	[ -d $tmp ] && del $tmp && cdir $tmp || cdir $tmp
	#copying gapps
	if [ -d $BASED/gapps ] && [ -n "$(ls -A $BASED/gapps 2>/dev/null)" ]; then
	cp -af $BASED/gapps/* $tmp/
	else
	# microg sources are optional: without them this variant is skipped
	# instead of failing the whole make run.
	printlog "[SKIP] <$BASED/gapps/> is empty - microG sources were not restored"
	printlog "       Run: sh build.sh restore litegappsx microg"
	return 0
	fi
	# litegapps system compress
	if [ "$apk_compessed_type" = litegapps_compress ]; then
	lgapps_unzip
	make_tar
	fi
	make_tar_arch
	make_archive
	make_flashable_litegappsx
}

#################################################
# restore / make / clean entrypoints
#################################################
litegappsx_variants(){
	local d
	for d in "$base"/core/litegappsx/*/; do
		[ -f "${d}config" ] && basename "$d"
	done
}

litegappsx_restore(){
	local i
	for i in $(get_config litegappsx.restore | sed "s/,/ /g"); do
		BASED="$base/core/litegappsx/$i"
		if [ -d "$BASED" ]; then
			_litegappsx_restore_variant
		else
			printlog "! [SKIP] litegappsx variant <$i> not found"
		fi
	done
}

litegappsx_make(){
	local LIST i
	if [ "$VARIANT" ]; then
	LIST=$VARIANT
	else
	LIST=`get_config litegappsx.type | sed "s/,/ /g"`
	fi
	for i in $LIST; do
		export VARIANT=$i
		BASED="$base/core/litegappsx/$i"
		if [ ! -d "$BASED" ]; then
			ERROR "[ERROR] litegappsx variant <$i> not found <$BASED>"
		fi
		_litegappsx_build_variant
	done
}

litegappsx_clean(){
	local v
	for v in $(litegappsx_variants); do
		clean_variant_dirs "$base/core/litegappsx/$v"
	done
}

#################################################
# restore body (moved from core/litegappsx/*/restore.sh)
#################################################

# microG components come from micro5k/microg-unofficial-installer:
#   - the APKs are Apache-2.0 (microG Project Team)
#   - the permission XMLs are CC0-1.0
# None of that project's GPL-3.0 shell code is copied into this repo; the
# download/layout logic below is this repo's own. The tree keeps the
# cross_system/ + cross_sdk/<api>/ shape installer/customize.sh's
# litegappsx() assembles per device.
# The big APKs are stored in Git LFS, where raw.githubusercontent.com returns
# the 134-byte pointer instead of the file; media.githubusercontent.com serves
# the real bytes. Try the media endpoint first and fall back to raw.
MICROG_MEDIA=https://media.githubusercontent.com/media/micro5k/microg-unofficial-installer/main/zip-content/origin
MICROG_SRC=https://raw.githubusercontent.com/micro5k/microg-unofficial-installer/main/zip-content/origin
MICROG_FILES="
priv-app/GmsCore.apk|system/priv-app/GmsCore/GmsCore.apk
priv-app/FakeStore.apk|system/priv-app/FakeStore/FakeStore.apk
framework/com.google.android.maps.jar|system/framework/com.google.android.maps.jar
etc/permissions/com.google.android.maps.xml|system/etc/permissions/com.google.android.maps.xml
etc/permissions/privapp-permissions-GmsCore.xml|system/etc/permissions/privapp-permissions-GmsCore.xml
etc/permissions/privapp-permissions-FakeStore.xml|system/etc/permissions/privapp-permissions-FakeStore.xml
"

# _microg_valid <file> <basename>: 0 when the download really is the payload
# (not a Git LFS pointer, an HTML error page or a truncated file).
_microg_valid(){
	local f="$1" n="$2"
	[ -s "$f" ] || return 1
	head -c 64 "$f" | grep -q 'git-lfs' && return 1
	case "$n" in
		*.apk|*.jar)
			# a real APK/JAR is a zip and far bigger than any error page
			[ "$(wc -c < "$f")" -ge 1024 ] || return 1
			[ "$(head -c 2 "$f")" = "PK" ] || return 1 ;;
		*.xml)
			# permission XMLs are tiny, so check their content instead
			grep -qE '<(permissions|exceptions)' "$f" || return 1 ;;
	esac
	return 0
}

_litegappsx_restore_variant(){
GAPPS_FILES=$BASED/files
GAPPS=$BASED/gapps
MODULES=$BASED/modules
MODULES_FILES=$BASED/modules_files
for i in $GAPPS $GAPPS_FILES $MODULES $MODULES_FILES; do
	[ ! -d $i ] && cdir $i
done
printlog " "
printlog "        AweGappsX MicroG restore"
printlog " "

del "$GAPPS/cross_system"
cdir "$GAPPS/cross_system"
NUM_6070=0
FAILED=0
for I in $MICROG_FILES; do
	NUM_6070=$((NUM_6070 + 1))
	D_SRC=${I%%|*}
	D_DST=${I#*|}
	D_NAME=$(basename "$D_SRC")
	D_CACHE=$GAPPS_FILES/microg/$D_NAME
	[ ! -d "$GAPPS_FILES/microg" ] && cdir "$GAPPS_FILES/microg"
	printlog "$NUM_6070. $D_NAME"
	# a Git LFS pointer or an error page must never be reused from the cache
	if [ -s "$D_CACHE" ] && ! _microg_valid "$D_CACHE" "$D_NAME"; then
		printlog "     Cached copy is invalid, downloading again"
		del "$D_CACHE"
	fi
	if [ ! -s "$D_CACHE" ]; then
		if ! curl -fL -o "$D_CACHE.part" "$MICROG_MEDIA/$D_SRC" 2>/dev/null \
			|| ! _microg_valid "$D_CACHE.part" "$D_NAME"; then
			del "$D_CACHE.part"
			# -f so an error page is never saved as the file
			if ! curl -fL -o "$D_CACHE.part" "$MICROG_SRC/$D_SRC" 2>/dev/null \
				|| ! _microg_valid "$D_CACHE.part" "$D_NAME"; then
				printlog "     Download status : Failed"
				del "$D_CACHE.part"
				FAILED=$((FAILED + 1))
				continue
			fi
		fi
		mv -f "$D_CACHE.part" "$D_CACHE"
		printlog "     Download status : Successful ($(du -sh "$D_CACHE" | cut -f1))"
	else
		printlog "     Cached : $(du -sh "$D_CACHE" | cut -f1)"
	fi
	# the destination path is relative to the cross_system root
	D_OUT="$GAPPS/cross_system/$D_DST"
	cdir "$(dirname "$D_OUT")"
	cp -pf "$D_CACHE" "$D_OUT"
done

if [ "$FAILED" -gt 0 ]; then
	printlog " "
	printlog "[FAIL] $FAILED microG file(s) could not be downloaded"
	printlog "       Source: $MICROG_SRC"
	printlog "       Drop the files by hand into <$GAPPS_FILES/microg/> and restore again."
	del "$GAPPS/cross_system"
	return 0
fi

# customize.sh needs a cross_sdk/<api> entry for every Android version the
# zip installs on; the common files live in cross_system, so these only hold
# a marker and keep the archive small.
for API_MG in 24 25 26 27 28 29 30 31 32 33 34 35 36 37; do
	cdir "$GAPPS/cross_sdk/$API_MG/system"
	echo "microG common files live in cross_system" > "$GAPPS/cross_sdk/$API_MG/system/.microg-common"
done

printlog " "
printlog "- Restore status : Successful"
}
