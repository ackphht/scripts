#!/bin/bash
tru='true'; fals='false';
#if [ "$1" = "-whatIf" ]; then whatIf=$tru; else whatIf=$fals; fi
[[ "$1" == "-whatIf" ]] && whatIf=$tru || whatIf=$fals
#[ $whatIf = $tru ] && echo "whatIf is set" || echo "whatIf is NOT set"
backupFolder=$HOME/backup/

if [[ ! -d $backupFolder ]]; then
	echo "backup folder '$backupFolder' not found"
	exit 1
fi

ts=$(date +%Y%m%d_%H%M%S)
IFS=$(echo -en '\n\b')	# keep the 'for' from splitting on spaces in names; but why does this only work with the '\b' in there ????
for f in $(find $backupFolder -type f -print); do
	#echo "checking file '$f' for restore"
	partPath=$(echo $f | sed -E "s_^${backupFolder}(.+)\$_\1_")
	justName=$(basename $f)
	if [[ "$(echo $justName | sed -E 's/^(etc_.+)$/etc/')" == "etc" || $justName == ".uuid" ]]; then
		#echo "skipping /etc file '$justName'"
		# skip files we copied out of /etc folder (they're just to look at):
		continue
	elif [[ "$(echo $justName | sed -E 's/^(dconf_.+)$/dconf/')" == "dconf" ]]; then
		#echo "skipping /dconf file '$justName'"
		# skip dconf settings files here; have to be handled separately below
		continue
	elif [[ $justName == ".bash_profile" || $justName == ".bashrc" || $justName == ".profile" || $justName == ".inputrc" ]]; then
		#echo "handling profile file '$justName'"
		# don't want to overwrite the existing files for these, so copy to another name, then we can manually diff them:
		newName="${HOME}/${justName}.fromBackup"
		if [[ -f $newName ]]; then
			echo "file '$newName' already exists; need to clean up from previous script run"
			exit 1
		fi
		[[ $whatIf != $tru ]] && cp $f $newName || echo "WhatIf: copying file '$f' to '$newName'"
	else
		#echo "handling file '$partPath'"
		# everything else, make a backup of existing files, then replace them:
		newName="${HOME}/${partPath}"	# assuming everything we backed up other than /etc stuff is from $HOME...
		fldr=$(dirname ${newName})
		if [[ ! -d $fldr ]]; then
			#echo "    creating folder '$fldr'"
			mkdir -p $fldr
		elif [[ -f $newName ]]; then
			backupName="${newName}.${ts}.bak"
			if [[ -f $backupName ]]; then
				echo "backup file '$backupName' already exists; need to clean up from previous script run"
				exit 1
			fi
			#echo "backing up existing file '$newName'"
			[[ $whatIf != $tru ]] && mv $newName $backupName || echo "WhatIf: moving file '$newName' to '$backupName'"
		fi
		[ $whatIf != $tru ] && cp $f $newName || echo "WhatIf: copying file '$f' to '$newName'"
	fi
done

#
# dconf settings:
#

restoreDconfFile() {
	if [[ -f $1 ]]; then
		echo importing dconf settings from \"$1\" to \"$2\"
		#dconf load $2 < $1
		[ $whatIf != $tru ] && dconf load $2 < $1 || echo "WhatIf: loading dconf file '$1'"
	fi
}

restoreDconfFile "$backupFolder/dconf_tillix" '/com/gexperts/Tillix/'	# Budgie's terminal
restoreDconfFile "$backupFolder/dconf_caja" '/org/caja/'
restoreDconfFile "$backupFolder/dconf_cinnamonScreensaver" '/org/cinnamon/desktop/screensaver/'
restoreDconfFile "$backupFolder/dconf_cinnamonPowerMngmnt" '/org/cinnamon/settings-daemon/plugins/power/'
restoreDconfFile "$backupFolder/dconf_gedit" '/org/gnome/gedit/'
restoreDconfFile "$backupFolder/dconf_gnomeTerminal" '/org/gnome/terminal/'
restoreDconfFile "$backupFolder/dconf_pluma" '/org/mate/pluma/'
restoreDconfFile "$backupFolder/dconf_matePowerManager" '/org/mate/power-manager/'
restoreDconfFile "$backupFolder/dconf_mateScreensaver" '/org/mate/screensaver/'
restoreDconfFile "$backupFolder/dconf_mateTerminal" '/org/mate/terminal/'
restoreDconfFile "$backupFolder/dconf_nemo" '/org/nemo/'
restoreDconfFile "$backupFolder/dconf_xed" '/org/x/editor/'
restoreDconfFile "$backupFolder/dconf_mousepad" '/org/xfce/mousepad/'

echo
echo
echo "completed"
echo
echo "if any user fonts were restored, you'll probably need to run:"
echo "    fc-cache -vf"
echo
