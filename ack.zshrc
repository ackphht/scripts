########################################
# from Kali's default .zshrc:
WORDCHARS=${WORDCHARS//\/} # Don't consider certain characters part of the word
# hide EOL sign ('%')
PROMPT_EOL_MARK=""

# not sure...
##setopt correct				# auto correct mistakes
#setopt interactivecomments		# allow comments in interactive mode
#setopt magicequalsubst			# enable filename expansion for arguments of the form ‘anything=expression’
##setopt nonomatch				# hide error message if there is no match for the pattern
##setopt notify					# report the status of background jobs immediately
#setopt numericglobsort			# sort filenames numerically when it makes sense
#setopt promptsubst				# enable command substitution in prompt

# enable completion features
autoload -Uz compinit
compinit -d ~/.cache/zcompdump
# not super sure yet what these next ones are doing...
zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' rehash true
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# History configurations
HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=2000
setopt hist_expire_dups_first	# delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups			# ignore duplicated commands history list
setopt hist_ignore_space		# ignore commands that start with space
setopt hist_verify				# show command with history expansion to user before running it
#setopt share_history			# share command history data

# enable color support of ls, less and man, and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
	test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
	export LS_COLORS="$LS_COLORS:ow=30;44:" # fix ls color for folders with 777 permissions

	alias ls='ls --color=auto'
	#alias dir='dir --color=auto'
	#alias vdir='vdir --color=auto'

	alias grep='grep --color=auto'
	alias fgrep='fgrep --color=auto'
	alias egrep='egrep --color=auto'
	alias diff='diff --color=auto'
	alias ip='ip --color=auto'

	export LESS_TERMCAP_mb=$'\E[1;31m'		# begin blink
	export LESS_TERMCAP_md=$'\E[1;36m'		# begin bold
	export LESS_TERMCAP_me=$'\E[0m'			# reset bold/blink
	export LESS_TERMCAP_so=$'\E[01;33m'		# begin reverse video
	export LESS_TERMCAP_se=$'\E[0m'			# reset reverse video
	export LESS_TERMCAP_us=$'\E[1;32m'		# begin underline
	export LESS_TERMCAP_ue=$'\E[0m'			# reset underline

	# Take advantage of $LS_COLORS for completion as well
	zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
	zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
fi

# enable auto-suggestions based on the history
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
	. /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
	# change suggestion color
	ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#999'
fi

# enable command-not-found if installed
if [ -f /etc/zsh_command_not_found ]; then
	. /etc/zsh_command_not_found
fi
########################################

########################################
# now my stuff:
# these could go on two lines (one for setopt, one for unsetopt), but i like the comments...
setopt		autocd			# change directory just by typing its name
setopt		extendedglob	# treat the '#', '~' and '^' characters as part of patterns for filename generation, etc.
unsetopt	beep			# DON"T beep on error
unsetopt	nomatch			# DON"T show error message if there is no match for the pattern
unsetopt	notify			# DON'T report the status of background jobs immediately

# get rid of highlighting text on paste
unset zle_bracketed_paste

bindkey -e											# emacs key bindings
# FYI: use "showkey -a" to see the keys; and for list of 'widgets', see "man zshzle" (or https://linux.die.net/man/1/zshzle or https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html#Standard-Widgets)
# think these are on by default anyway but just to be sure, in case I get used to them:
bindkey '^A'		beginning-of-line				# ctrl-A
bindkey '^E'		end-of-line						# ctrl-E
bindkey '^U' 		kill-whole-line					# ctrl-U
bindkey '^[[3~'		delete-char						# delete
# mine:
bindkey '^[[1;5C'	forward-word					# ctrl + ->
bindkey '^[[1;5D'	backward-word					# ctrl + <-
bindkey '^[[1~'		beginning-of-line				# home (linux console ??)
bindkey '^[[H'		beginning-of-line				# home (xterm)
bindkey '^[OH'		beginning-of-line				# home (gnome-terminal ??)
bindkey '^[[4~'		end-of-line						# end (linux console ??)
bindkey '^[[F'		end-of-line						# end (xterm)
bindkey '^[OF'		end-of-line						# end (gnome-terminal)
bindkey '^[' 		kill-whole-line					# esc
bindkey '^H' 		backward-delete-word			# Ctrl-Backspace
bindkey '^[[3;5~'	delete-word						# ctrl-delete
bindkey '^[[19~'	history-search-backward			# F8
bindkey '^[[19;2~'	history-search-forward			# Shift-F8


test -r ~/scripts/ackShellStuff.sh && source ~/scripts/ackShellStuff.sh || true