BASED="`dirname $(readlink -f "$0")`"

arch="
arm64

"
sdk="
34
"


CORE_MODULE () {
	local input=$1
	local output=$2
	local list="
GoogleServicesFramework
GmsCore                  
GoogleCalendarSyncAdapter
PlayStore
Phonesky
GoogleContactsSyncAdapter
"
for Y in $(ls -1 $input); do

 for G in $list; do
 skip=false
 if [ $Y = $G ]; then
 	skip=true
 	break
 fi
 done
 
 if ! $skip; then
 rm -rf $2/$Y
 mkdir -p $2/$Y
 echo "- Copying <$input/$Y> to <$output/$Y>"
 cp -rdf $1/$Y $2/
 else
 echo "- Skip $Y"
 fi
done
	}

	
	
	
PIXEL () {
	local variant=pixel
	#pixel
	local IN=$BASED/packages/output/$ARCH/$SDK/
	local OUT=$BASED/core/litegapps/pixel/modules/$ARCH/$SDK/
	rm -rf $OUT
	CORE_MODULE $BASED/packages/output/$ARCH/$SDK/core $BASED/core/litegapps/pixel/modules/$ARCH/$SDK/core
	cp -rdf $BASED/packages/output/$ARCH/$SDK/gapps $BASED/core/litegapps/pixel/modules/$ARCH/$SDK/
	bash $BASED/build.sh make litegapps $variant $ARCH $SDK
	[ ! -d $RELEASE/$variant ] && mkdir -p $RELEASE/$variant
	RIN=$BASED/output/litegapps/$ARCH/$SDK/$variant 
	ROUT=$RELEASE/$variant
	for U in $(ls -1 $RIN); do
	echo "- Release <$RIN/$U> to <$ROUT>"
	cp -rdf $RIN/$U $ROUT/
	rm -rf $RIN/$U
	done
	
	}
	
BASIC (){
	local variant=basic
	local list="
	AndroidAuto
	Arcore
	DevicePolicy
	GoogleDialer
	GoogleContacts
	LocationHistory
	MarkupGoogle
	SoundPicker
	Wellbeing
	"
	
	local IN=$BASED/packages/output/$ARCH/$SDK/
	local OUT=$BASED/core/litegapps/basic/modules/$ARCH/$SDK/
	rm -rf $OUT
	CORE_MODULE $BASED/packages/output/$ARCH/$SDK/core $BASED/core/litegapps/basic/modules/$ARCH/$SDK/core
	
	for M in $(ls -1 $BASED/packages/output/$ARCH/$SDK/gapps) ; do
	for M1 in $list; do
	local check=false
	if [ $M = $M1 ]; then
	local check=true
	break
	fi
	done
	
	if $check; then
	echo "+ Copying <$BASED/packages/output/$ARCH/$SDK/gapps/$M> To <$BASED/core/litegapps/basic/modules/$ARCH/$SDK/gapps/>"
	
	mkdir -p $BASED/core/litegapps/basic/modules/$ARCH/$SDK/gapps/$M
	cp -rdf $BASED/packages/output/$ARCH/$SDK/gapps/$M $BASED/core/litegapps/basic/modules/$ARCH/$SDK/gapps/
	else
	echo "! Skipping $M"
	fi
	done
	
	bash $BASED/build.sh make litegapps $variant $ARCH $SDK
	[ ! -d $RELEASE/$variant ] && mkdir -p $RELEASE/$variant
	RIN=$BASED/output/litegapps/$ARCH/$SDK/$variant 
	ROUT=$RELEASE/$variant
	for U in $(ls -1 $RIN); do
	echo "- Release <$RIN/$U> to <$ROUT>"
	cp -rdf $RIN/$U $ROUT/
	rm -rf $RIN/$U
	done
	}
	
	
	
	
	
LITE (){
	local variant=lite

	local IN=$BASED/packages/output/$ARCH/$SDK/
	local OUT=$BASED/core/litegapps/lite/modules/$ARCH/$SDK/
	rm -rf $OUT
	bash $BASED/build.sh make litegapps $variant $ARCH $SDK
	[ ! -d $RELEASE/$variant ] && mkdir -p $RELEASE/$variant
	RIN=$BASED/output/litegapps/$ARCH/$SDK/$variant
	ROUT=$RELEASE/$variant
	for U in $(ls -1 $RIN); do
		echo "- Release <$RIN/$U> to <$ROUT>"
		cp -rdf $RIN/$U $ROUT/
		rm -rf $RIN/$U
	done
	}

	
	
AWE (){
	local variant=awe
	local list="
	Chrome
	GoogleKeyboard
	SoundPicker
	"

	local IN=$BASED/packages/output/$ARCH/$SDK/
	local OUT=$BASED/core/litegapps/awe/modules/$ARCH/$SDK/
	rm -rf $OUT
	CORE_MODULE $BASED/packages/output/$ARCH/$SDK/core $BASED/core/litegapps/awe/modules/$ARCH/$SDK/core

	for M in $(ls -1 $BASED/packages/output/$ARCH/$SDK/gapps) ; do
	for M1 in $list; do
	local check=false
	if [ $M = $M1 ]; then
	local check=true
	break
	fi
	done

	if $check; then
	echo "+ Copying <$BASED/packages/output/$ARCH/$SDK/gapps/$M> To <$BASED/core/litegapps/awe/modules/$ARCH/$SDK/gapps/>"

	mkdir -p $BASED/core/litegapps/awe/modules/$ARCH/$SDK/gapps/$M
	cp -rdf $BASED/packages/output/$ARCH/$SDK/gapps/$M $BASED/core/litegapps/awe/modules/$ARCH/$SDK/gapps/
	else
	echo "! Skipping $M"
	fi
	done

	bash $BASED/build.sh make litegapps $variant $ARCH $SDK
	[ ! -d $RELEASE/$variant ] && mkdir -p $RELEASE/$variant
	RIN=$BASED/output/litegapps/$ARCH/$SDK/$variant
	ROUT=$RELEASE/$variant
	for U in $(ls -1 $RIN); do
	echo "- Release <$RIN/$U> to <$ROUT>"
	cp -rdf $RIN/$U $ROUT/
	rm -rf $RIN/$U
	done
	}

MAKE_ADDON(){
	bash $BASED/packages/make make $ARCH $SDK
	ADDON_RELEASE=/home/frs/project/litegapps/addon/$ARCH/$SDK/
	rm -rf $ADDON_RELEASE
	mkdir -p $ADDON_RELEASE
	echo "- Release Addon <$BASED/packages/output/$ARCH/$SDK/> <$ADDON_RELEASE>"
	cp -rdf $BASED/packages/output/$ARCH/$SDK/* $ADDON_RELEASE
	}
	
MAKE_LITEGAPPS(){
	
	local RELEASE=/home/frs/project/litegapps/litegapps/$ARCH/$SDK
	for LIST_MAKSU in $(find $BASED/packages/output -name MAKSU* -type f); do
		echo "-- Removing <$LIST_MAKSU>"
		rm -rf $LIST_MAKSU
	done

	for LIST_RECOVERY in $(find $BASED/packages/output -name RECOVERY* -type f); do
		echo "-- Removing <$LIST_RECOVERY>"
		rm -rf $LIST_RECOVERY
	done

	rm -rf $BASED/output
	
	case $ARCH in
	arm64)
	if [ $SDK -le 25 ]; then
	# The addon source only exists from SDK 26 on, so only lite (which
	# needs no addon) is built below that.
	LITE
	else
	# Android 8.0 (SDK 26) and up - every variant needs the addon.
	PIXEL
	BASIC
	AWE
	LITE
	fi
	;;
	*)
	echo "! <$ARCH> is not built any more, only arm64"
	;;
	esac
	rm -rf $BASED/tmp_files
	PRUNE_RELEASES $RELEASE
	}

# Keep only the newest $SF_KEEP_RELEASES (15) dated releases (YYYY-MM-DD) in
# every variant folder of one arch/sdk release dir; older ones are deleted.
# Folders not named as an ISO date (old v3.0-style releases) are left alone.
# Same rule as sf-prune.sh, which does this remotely for vps-build.sh.
PRUNE_RELEASES(){
	local KEEP=${SF_KEEP_RELEASES:-15} VDIR DATES COUNT OLD
	for VDIR in $1/*/; do
		[ -d "$VDIR" ] || continue
		DATES=$(ls -1d "$VDIR"[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] 2>/dev/null | sort)
		COUNT=$(printf '%s\n' "$DATES" | grep -c .)
		[ "$COUNT" -gt "$KEEP" ] || continue
		for OLD in $(printf '%s\n' "$DATES" | head -n $((COUNT - KEEP))); do
			echo "- Pruning old release <$OLD> (keeping the newest $KEEP)"
			rm -rf "$OLD"
		done
	done
	}
UNZIP_FILE_SERVER(){
	local input=$HOMEE/files-server/package/$ARCH/${SDK}.zip
	local output=$HOMEE/build/litegapps/packages/files/$ARCH/$SDK/
	rm -rf $output
	mkdir -p $output
	unzip -o $input -d $output
	
	}
UNZIP_GAPPS(){
	local input=$HOMEE/files-server/litegapps/$ARCH/$SDK/${SDK}.zip
	local input_lite=$HOMEE/files-server/litegapps/$ARCH/$SDK/${SDK}-lite.zip
	for ON in lite pixel basic awe; do
		local output=$HOMEE/build/litegapps/core/litegapps/$ON/gapps/$ARCH/$SDK/
		rm -rf $output
		mkdir -p $output
		if [ $ON = lite ]; then
			if [ -f $input_lite ]; then
			echo "- Extract <$input_lite> to <$output>"
			unzip -o $input_lite -d $output >/dev/null

			else
			echo "- Extract <$input> to <$output>"
			unzip -o $input -d $output >/dev/null
			fi
		else
		echo "- Extract <$input> to <$output>"
		unzip -o $input -d $output >/dev/null
		fi
	done


	}

#################################################
# Build All - resumable batch build across every arch x sdk
#
# The SourceForge build VPS has a hard 4-hour job time limit, so this
# cannot build everything (arm64 x Android 7.0-17, i.e. SDK 24-37) in one
# run. Instead it builds BUILD_ALL_BATCH targets per
# invocation (SDK descending from 37 down to 24), records each finished
# arch/sdk in a state file,
# and stops. Reboot the VPS job, run sf-build.sh again, pick this same
# menu option, and it resumes from whatever is not yet in the state file.
#
# To force a rebuild of one specific arch/sdk regardless of progress, just
# use the normal menu (select that arch/sdk at startup, then options 1+2)
# - Build All's progress tracking does not affect the manual menu at all.
#################################################
BUILD_ALL_STATE="$BASED/sf-build-progress.log"
# Only arm64 is built any more: arm, x86 and x86_64 are gone and nothing is
# restored or built for them.
BUILD_ALL_ARCHES="arm64"
BUILD_ALL_SDKS="37 36 35 34 33 32 31 30 29 28 27 26 25 24"
BUILD_ALL_BATCH=4

BUILD_ALL(){
	touch "$BUILD_ALL_STATE"
	local done_count=0
	local BA BS
	for BA in $BUILD_ALL_ARCHES; do
		for BS in $BUILD_ALL_SDKS; do
			if grep -qx "$BA $BS" "$BUILD_ALL_STATE"; then
				continue
			fi
			echo " "
			echo "==================================================="
			echo " Build All : ARCH=$BA SDK=$BS  ($((done_count + 1))/$BUILD_ALL_BATCH this session)"
			echo "==================================================="
			export ARCH=$BA
			export SDK=$BS
			UNZIP_FILE_SERVER
			UNZIP_GAPPS
			MAKE_ADDON
			MAKE_LITEGAPPS
			echo "$BA $BS" >> "$BUILD_ALL_STATE"
			done_count=$((done_count + 1))
			if [ $done_count -ge $BUILD_ALL_BATCH ]; then
				echo " "
				echo "==================================================="
				echo " Batch of $BUILD_ALL_BATCH done for this session."
				echo " Reboot this VPS job now, then re-run sf-build.sh"
				echo " and pick 'Build All (continue)' again to resume."
				echo "==================================================="
				echo " "
				return 0
			fi
		done
	done
	echo " "
	echo "Build All: every arch x sdk combination is already built - nothing left to do."
	echo "(remove $BUILD_ALL_STATE to start over)"
	echo " "
	}

SHOW_BUILD_ALL_PROGRESS(){
	touch "$BUILD_ALL_STATE"
	local total=0 left=0 BA BS
	echo " "
	echo "Build All progress ($BUILD_ALL_STATE):"
	for BA in $BUILD_ALL_ARCHES; do
		for BS in $BUILD_ALL_SDKS; do
			total=$((total + 1))
			if grep -qx "$BA $BS" "$BUILD_ALL_STATE"; then
				echo "  [x] $BA $BS"
			else
				echo "  [ ] $BA $BS"
				left=$((left + 1))
			fi
		done
	done
	echo " "
	echo "  Done: $((total - left)) / $total   Remaining: $left"
	echo " "
	}

CLEAN_RELEASE(){
	echo "- Remove Old Build"
	
	for J in $(ls -1 $HOMEE/litegapps); do
		for R in $(ls -1 $HOMEE/litegapps/$J); do
		#arch
			for H in $(ls -1 $HOMEE/litegapps/$J/$R); do
			#sdk
				for K in $(ls -1 $HOMEE/litegapps/$J/$R/$H); do
				  if [ -d $HOMEE/litegapps/$J/$R/$H/$K ]; then
					for V in $(ls -1 $HOMEE/litegapps/$J/$R/$H/$K/ | sort -n | tail -n +11); do
					
						echo " Remove $HOME/litegapps/$J/$R/$H/$K/$V"
						#sort -n | tail -n +11
					done
					
				  fi
				done
			done
		done
	done
	echo "# click enter"
	read r
	
	}
while true; do
HOMEE=/home/frs/project/litegapps
echo -n "    Select architecture : "
read selarch
case $selarch in
arm64)
ARCH=$selarch
break
;;
*)
echo "! $selarch not found list"
;;
esac
done
while true; do
echo -n "    Select SDK : "
read selsdk
case $selsdk in
25 | 26 | 27 | 28 | 29 | 30 | 31 | 32 | 33 | 34 | 35 | 36 | 37)
export SDK=$selsdk
break
;;
*)
echo "! $selsdk not found list"
;;
esac
done


while true; do
echo " "
#echo "  Home Size : $(du -sh /home)"
echo "  ARCH = $ARCH"
echo "  SDK  = $SDK"
echo " "
echo "1. Make Addon And Release"
echo "2. Make LiteGapps And Release"
echo "3. Extract zip from file-server"
echo "4. Extract ZIP GAPPS"
echo "5. Remove Old Build"
echo "6. Build All (continue) - batches of $BUILD_ALL_BATCH, all arch x Android 7.0-17"
echo "7. Show Build All progress"
echo "8. Exit"
echo " "
echo -n " Select : "
read menuu
case $menuu in
1) MAKE_ADDON ;;
2) MAKE_LITEGAPPS ;;
3)
UNZIP_FILE_SERVER
;;
4)
UNZIP_GAPPS
;;
5)
CLEAN_RELEASE
;;
6)
BUILD_ALL
;;
7)
SHOW_BUILD_ALL_PROGRESS
;;
8)
break ;;
*)
echo "! Not found command : $menuu"
;;
esac


done

