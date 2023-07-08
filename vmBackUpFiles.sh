#!/bin/bash
backupFolder=$HOME/backup_$HOSTNAME

verifyFolder() {
	if [[ ! -d $1 ]]; then
		#echo "    creating folder '$1'"
		mkdir -p $1
	fi
}

backUpFile() {
	local origFilename=$1
	local backUpFilename=$backupFolder/$2
	#echo "backUpFile: origFilename = '$origFilename' / backUpFilename = '$backUpFilename'"

	if [[ -f $origFilename ]]; then
		#echo "    found file '$origFilename'"
		local fldr=$(dirname ${backUpFilename})
		#if [ ! -d $fldr ]; then
		#	#echo "    creating folder '$fldr'"
		#	mkdir -p $fldr
		#fi
		verifyFolder $fldr
		echo "backing up file '$origFilename' to '$backUpFilename'"
		cp $origFilename $backUpFilename
	#else
	#	echo "    file '$origFilename' does not exist"
	fi
}

backupMultiFiles() {
	local origFileSpec=$1
	local backUpTo=$backupFolder/$2
	#echo "backupMultiFiles: origFileSpec = '$origFileSpec' / backUpTo = '$backUpTo'"
	#if [ -f $origFileSpec ]; then
	if compgen -G $origFileSpec > /dev/null; then
		#echo "    found filespec '$origFileSpec'"
		#if [ ! -d $backUpTo ]; then
		#	#echo "    creating folder '$backUpTo'"
		#	mkdir -p $backUpTo
		#fi
		verifyFolder $backUpTo
		echo "backing files '$origFileSpec' to '$backUpTo'"
		cp $origFileSpec $backUpTo
	#else
	#	echo "    filespec '$origFileSpec' does not exist"
	fi
}

#if [ ! -d $backupFolder ]; then
#	mkdir -p $backupFolder
#fi
verifyFolder $backupFolder

if type -p dconf >/dev/null && [[ -f "$HOME/.config/dconf/user" ]]; then
	if dconf list /com/gexperts/Tillix/ > /dev/null; then dconf dump /com/gexperts/Tillix/ > "$backupFolder/dconf_tillix"; fi	# Budgie's terminal
	if dconf list /org/caja/ > /dev/null; then dconf dump /org/caja/ > "$backupFolder/dconf_caja"; fi
	if dconf list /org/cinnamon/desktop/screensaver/ > /dev/null; then dconf dump /org/cinnamon/desktop/screensaver/ > "$backupFolder/dconf_cinnamonScreensaver"; fi
	if dconf list /org/cinnamon/settings-daemon/plugins/power/ > /dev/null; then dconf dump /org/cinnamon/settings-daemon/plugins/power/ > "$backupFolder/dconf_cinnamonPowerMngmnt"; fi
	if dconf list /org/gnome/gedit/ > /dev/null; then dconf dump /org/gnome/gedit/ > "$backupFolder/dconf_gedit"; fi
	if dconf list /org/gnome/terminal/ > /dev/null; then dconf dump /org/gnome/terminal/ > "$backupFolder/dconf_gnomeTerminal"; fi	# cinnamon uses this
	if dconf list /org/mate/pluma/ > /dev/null; then dconf dump /org/mate/pluma/ > "$backupFolder/dconf_pluma"; fi
	if dconf list /org/mate/power-manager/ > /dev/null; then dconf dump /org/mate/power-manager/ > "$backupFolder/dconf_matePowerManager"; fi
	if dconf list /org/mate/screensaver/ > /dev/null; then dconf dump /org/mate/screensaver/ > "$backupFolder/dconf_mateScreensaver"; fi
	if dconf list /org/mate/terminal/ > /dev/null; then dconf dump /org/mate/terminal/ > "$backupFolder/dconf_mateTerminal"; fi
	if dconf list /org/nemo/ > /dev/null; then dconf dump /org/nemo/ > "$backupFolder/dconf_nemo"; fi
	if dconf list /org/x/editor/ > /dev/null; then dconf dump /org/x/editor/ > "$backupFolder/dconf_xed"; fi
	if dconf list /org/xfce/mousepad/ > /dev/null; then dconf dump /org/xfce/mousepad/ > "$backupFolder/dconf_mousepad"; fi
fi

backUpFile '/etc/hosts' 'etc_hosts'
backUpFile '/etc/profile' 'etc_profile'
backUpFile '/etc/profile.local' 'etc_profile.local'
backUpFile '/etc/bashrc' 'etc_bashrc'
backUpFile '/etc/bash.bashrc' 'etc_bash.bashrc'
backUpFile '/etc/zshrc' 'etc_zshrc'
backUpFile '/etc/zprofile' 'etc_zprofile'
backUpFile '/etc/zshenv' 'etc_zshenv'
backUpFile '/etc/zlogin' 'etc_zlogin'
backUpFile '/etc/environment' 'etc_environment'
backUpFile '/etc/initscript' 'etc_initscript'
backUpFile '/etc/inputrc' 'etc_inputrc'
backUpFile '/etc/login.defs' 'etc_login.defs'
backUpFile '/etc/samba/smb.conf' 'etc_samba_smb.conf'
backUpFile "$HOME/.alias" '.alias'
backUpFile "$HOME/.bash_aliases" '.bash_aliases'
backUpFile "$HOME/.bash_profile" '.bash_profile'
backUpFile "$HOME/.bashrc" '.bashrc'
backUpFile "$HOME/.zshrc" '.zshrc'
backUpFile "$HOME/.zprofile" '.zprofile'
backUpFile "$HOME/.zshenv" '.zshenv'
backUpFile "$HOME/.profile" '.profile'
backUpFile "$HOME/.inputrc" '.inputrc'
backUpFile "$HOME/.gitconfig" '.gitconfig'
backUpFile "$HOME/.gitignore" '.gitignore'
backUpFile "$HOME/installNerdFont.sh" 'installNerdFont.sh'
backUpFile "$HOME/installPwsh.sh" 'installPwsh.sh'
backUpFile "$HOME/zeroFreeSpace.ps1" 'zeroFreeSpace.ps1'
backUpFile "$HOME/.config/dolphinrc" '.config/dolphinrc'
backUpFile "$HOME/.config/katerc" '.config/katerc'
backUpFile "$HOME/.config/kinfocenterrc" '.config/kinfocenterrc'
backUpFile "$HOME/.config/konsolerc" '.config/konsolerc'
backUpFile "$HOME/.config/kscreenlockerrc" '.config/kscreenlockerrc'
backUpFile "$HOME/.config/kwriterc" '.config/kwriterc'
backUpFile "$HOME/.config/mimeapps.list" '.config/mimeapps.list'
backUpFile "$HOME/.config/systemmonitorrc" '.config/systemmonitorrc'
backUpFile "$HOME/.config/systemsettingsrc" '.config/systemsettingsrc'
backUpFile "$HOME/.config/Code/User/keybindings.json" '.config/Code/User/keybindings.json'
backUpFile "$HOME/.config/Code/User/settings.json" '.config/Code/User/settings.json'
backUpFile "$HOME/.config/filezilla/filezilla.xml" '.config/filezilla/filezilla.xml'
backUpFile "$HOME/.config/filezilla/layout.xml" '.config/filezilla/layout.xml'
backUpFile "$HOME/.config/filezilla/sitemanager.xml" '.config/filezilla/sitemanager.xml'
backUpFile "$HOME/.config/pacmanfm-qt/lxqt/settings.conf" '.config/pacmanfm-qt/lxqt/settings.conf'
backUpFile "$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1" '.config/powershell/Microsoft.PowerShell_profile.ps1'
backUpFile "$HOME/.config/xfce4/terminal/terminalrc" '.config/xfce4/terminal/terminalrc'
backUpFile "$HOME/.local/share/user-places.xbel" '.local/share/user-places.xbel'
backupMultiFiles "/etc/zsh/*" 'etc_zsh/'
backupMultiFiles "$HOME/Documents/*" 'Documents/'
backupMultiFiles "$HOME/Pictures/*" 'Pictures/'
backupMultiFiles "$HOME/bin/*" 'bin/'
backupMultiFiles "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/*" '.config/xfce4/xfconf/xfce-perchannel-xml/'	# changing these files doesn't seem to do anything, so not sure these are correct to back up
backupMultiFiles "$HOME/.local/bin/*" '.local/bin/'
backupMultiFiles "$HOME/.local/share/fonts/*" '.local/share/fonts/'
backupMultiFiles "$HOME/.local/share/konsole/*" '.local/share/konsole/'
backupMultiFiles "$HOME/.local/share/plasma-systemmonitor/*" '.local/share/plasma-systemmonitor/'
backupMultiFiles "$HOME/.ssh/*" '.ssh/'
