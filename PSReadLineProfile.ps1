# started from PSReadLine's SamplePSReadLineProfile.ps1; more stuff in there...
# https://github.com/PowerShell/PSReadLine
# https://learn.microsoft.com/en-us/powershell/module/psreadline/about/about_psreadline
# https://learn.microsoft.com/en-us/powershell/module/psreadline/about/about_psreadline_functions

using namespace System.Management.Automation
using namespace System.Management.Automation.Language

$mod = Import-Module -Name PSReadLine -PassThru

$_isWindows = ($PSEdition -ne 'Core' -or $IsWindows)

Set-PSReadLineOption -EditMode 'Windows'
if ($mod.Version -gt ([System.Version]'2.2.2')) {
	Set-PSReadLineOption -PredictionViewStyle 'ListView'
}

# Searching for commands with up/down arrow is really handy. The
# option "moves to end" is useful if you want the cursor at the end
# of the line while cycling through history like it does w/o searching,
# without that option, the cursor will remain at the position it was
# when you used up arrow, which can be useful if you forget the exact
# string you started the search on.
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Chord 'UpArrow' -Function 'HistorySearchBackward'
Set-PSReadLineKeyHandler -Chord 'DownArrow' -Function 'HistorySearchForward'

#Set-PSReadLineKeyHandler -HistoryNoDuplicates	# doesn't do what you think; only keeps dupes from being shown; they still get added to history; and it's set to True by default anyway

#
# try to make different OSes behave the same:
#
if ($mod.Version -ge ([System.Version]'2.0.1')) {	# -Chord added with v2.0.1; don't know how to search for it otherwise, and ... whatever
	$kh = Get-PSReadLineKeyHandler -Chord 'Ctrl+h'
	if ($kh -and $kh.Function -eq 'BackwardDeleteChar') {
		# windows has Ctrl+h bound to Backspace, so remove that; probably don't have to do this since we're rebinding below, but...
		Remove-PSReadLineKeyHandler -Chord 'Ctrl+h'
	}
	$kh = Get-PSReadLineKeyHandler -Chord 'Alt+F7'
	if ($kh -and $kh.Function -eq 'ClearHistory') {
		# not really sure what this does, don't want to hit by accident:
		Remove-PSReadLineKeyHandler -Chord 'Alt+F7'
	}
}
Set-PSReadLineKeyHandler -Chord 'Ctrl+h' -Function 'BackwardKillWord'				# in *nix shells, this is same as Ctrl+Backspace, so bind it to this too
Set-PSReadLineKeyHandler -Chord 'Ctrl+u' -Function 'RevertLine'						# used in *nix shells, so add it; Escape also bound by default
Set-PSReadLineKeyHandler -Chord 'Ctrl+a' -Function 'BeginningOfLine'				# used in *nix shells, so keep it for consistency; Home also bound by default
Set-PSReadLineKeyHandler -Chord 'Ctrl+e' -Function 'EndOfLine'						# used in *nix shells, so keep it for consistency; End also bound by default
if ($mod.Version -ge ([System.Version]'2.2.2')) {	# ForwardDeleteInput added with 2.2.2 (but think it's just a renamed ForwardDeleteLine ???, so that's we'll use for older)
	Set-PSReadLineKeyHandler -Chord 'Ctrl+k' -Function 'ForwardDeleteInput'				# used in *nix shells, so keep it for consistency; Ctrl+End also bound
	Set-PSReadLineKeyHandler -Chord 'Ctrl+End' -Function 'ForwardDeleteInput'			# on by default for Win but not others
} else {
	Set-PSReadLineKeyHandler -Chord 'Ctrl+k' -Function 'ForwardDeleteLine'				# used in *nix shells, so keep it for consistency; Ctrl+End also bound
	Set-PSReadLineKeyHandler -Chord 'Ctrl+End' -Function 'ForwardDeleteLine'			# on by default for Win but not others
}
Set-PSReadLineKeyHandler -Chord 'Ctrl+Delete' -Function 'KillWord'					# on by default for Win but not others
Set-PSReadLineKeyHandler -Chord 'Ctrl+Spacebar' -Function 'MenuComplete'			# on by default for Win but not others
Set-PSReadLineKeyHandler -Chord 'PageDown' -Function 'ScrollDisplayDown'			# on by default for Win but not others
Set-PSReadLineKeyHandler -Chord 'Ctrl+PageDown' -Function 'ScrollDisplayDownLine'	# on by default for Win but not others
Set-PSReadLineKeyHandler -Chord 'PageUp' -Function 'ScrollDisplayUp'				# on by default for Win but not others
Set-PSReadLineKeyHandler -Chord 'Ctrl+PageUp' -Function 'ScrollDisplayUpLine'		# on by default for Win but not others
Set-PSReadLineKeyHandler -Chord 'Ctrl+Alt+A' -Function 'SelectAll'					# by default this is Ctrl+a, but rebound that above; and Ctrl+Shift+A is used by MS Terminal

# CaptureScreen is good for blog posts or email showing a transaction
# of what you did when asking for help or demonstrating a technique.
Set-PSReadLineKeyHandler -Chord 'Ctrl+d,Ctrl+c' -Function 'CaptureScreen'

if ($_isWindows) {
	# This key handler shows the entire or filtered history using Out-GridView. The
	# typed text is used as the substring pattern for filtering. A selected command
	# is inserted to the command line without invoking. Multiple command selection
	# is supported, e.g. selected by Ctrl + Click.
	Set-PSReadLineKeyHandler -Key 'F7' `
							-BriefDescription History `
							-LongDescription 'Show command history' `
							-ScriptBlock {
		$pattern = $null
		[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$pattern, [ref]$null)
		if ($pattern) {
			$pattern = [regex]::Escape($pattern)
		}

		$history = [System.Collections.ArrayList]@(
			$last = ''; $lines = '';
			foreach ($line in [System.IO.File]::ReadLines((Get-PSReadLineOption).HistorySavePath)) {
				if ($line.EndsWith('`')) {
					$line = $line.Substring(0, $line.Length - 1)
					$lines = if ($lines) { "$lines`n$line" } else { $line }
					continue
				}
				if ($lines) {
					$line = "$lines`n$line"
					$lines = ''
				}
				if (($line -cne $last) -and (!$pattern -or ($line -match $pattern))) {
					$last = $line
					$line
				}
			}
		)
		$history.Reverse()

		$command = $history | Out-GridView -Title History -PassThru
		if ($command) {
			[Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
			[Microsoft.PowerShell.PSConsoleReadLine]::Insert(($command -join "`n"))
		}
	}

	# F1 for help on the command line - naturally
	Set-PSReadLineKeyHandler -Key 'F1' `
							-BriefDescription CommandHelp `
							-LongDescription 'Open the help window for the current command' `
							-ScriptBlock {
		param($key, $arg)
		$ast = $null; $tokens = $null; $errors = $null; $cursor = $null;
		[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)
		$commandAst = $ast.FindAll( {
				$node = $args[0]
				$node -is [CommandAst] -and $node.Extent.StartOffset -le $cursor -and $node.Extent.EndOffset -ge $cursor
			}, $true) | Select-Object -Last 1

		if ($commandAst -ne $null) {
			$commandName = $commandAst.GetCommandName()
			if ($commandName -ne $null) {
				$command = $ExecutionContext.InvokeCommand.GetCommand($commandName, 'All')
				if ($command -is [AliasInfo]) {
					$commandName = $command.ResolvedCommandName
				}
				if ($commandName -ne $null) {
					Get-Help $commandName -ShowWindow
				}
			}
		}
	}
}

#region Smart Insert/Delete
# The next four key handlers are designed to make entering matched quotes
# parens, and braces a nicer experience. I'd like to include functions
# in the module that do this, but this implementation still isn't as smart
# as ReSharper, so I'm just providing it as a sample.

Set-PSReadLineKeyHandler -Key '"', "'" `
						-BriefDescription SmartInsertQuote `
						-LongDescription 'Insert paired quotes if not already on a quote' `
						-ScriptBlock {
	param($key, $arg)

	$quote = $key.KeyChar

	$selectionStart = $null; $selectionLength = $null;
	[Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)
	$line = $null; $cursor = $null;
	[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

	# If text is selected, just quote it without any smarts
	if ($selectionStart -ne -1) {
		[Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $quote + $line.SubString($selectionStart, $selectionLength) + $quote)
		[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
		return
	}

	$ast = $null; $tokens = $null; $parseErrors = $null;
	[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$parseErrors, [ref]$null)

	function FindToken {
		param($tokens, $cursor)

		foreach ($token in $tokens) {
			if ($cursor -lt $token.Extent.StartOffset) { continue }
			if ($cursor -lt $token.Extent.EndOffset) {
				$result = $token
				$token = $token -as [StringExpandableToken]
				if ($token) {
					$nested = FindToken $token.NestedTokens $cursor
					if ($nested) { $result = $nested }
				}
				return $result
			}
		}
		return $null
	}

	$token = FindToken $tokens $cursor

	# If we're on or inside a **quoted** string token (so not generic), we need to be smarter
	if ($token -is [StringToken] -and $token.Kind -ne [TokenKind]::Generic) {
		# If we're at the start of the string, assume we're inserting a new string
		if ($token.Extent.StartOffset -eq $cursor) {
			[Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote ")
			[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
			return
		}

		# If we're at the end of the string, move over the closing quote if present.
		if ($token.Extent.EndOffset -eq ($cursor + 1) -and $line[$cursor] -eq $quote) {
			[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
			return
		}
	}

	if ($null -eq $token -or
		$token.Kind -eq [TokenKind]::RParen -or $token.Kind -eq [TokenKind]::RCurly -or $token.Kind -eq [TokenKind]::RBracket) {
		if ($line[0..$cursor].Where{ $_ -eq $quote }.Count % 2 -eq 1) {
			# Odd number of quotes before the cursor, insert a single quote
			[Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
		} else {
			# Insert matching quotes, move cursor to be in between the quotes
			[Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote")
			[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
		}
		return
	}

	# If cursor is at the start of a token, enclose it in quotes.
	if ($token.Extent.StartOffset -eq $cursor) {
		if ($token.Kind -eq [TokenKind]::Generic -or $token.Kind -eq [TokenKind]::Identifier -or
			$token.Kind -eq [TokenKind]::Variable -or $token.TokenFlags.hasFlag([TokenFlags]::Keyword)) {
			$end = $token.Extent.EndOffset
			$len = $end - $cursor
			[Microsoft.PowerShell.PSConsoleReadLine]::Replace($cursor, $len, $quote + $line.SubString($cursor, $len) + $quote)
			[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($end + 2)
			return
		}
	}

	# We failed to be smart, so just insert a single quote
	[Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
}

Set-PSReadLineKeyHandler -Key '(', '{', '[' `
						-BriefDescription InsertPairedBraces `
						-LongDescription 'Insert matching braces' `
						-ScriptBlock {
	param($key, $arg)

	$closeChar = switch ($key.KeyChar) {
		<#case#> '(' { [char]')'; break }
		<#case#> '{' { [char]'}'; break }
		<#case#> '[' { [char]']'; break }
	}

	$selectionStart = $null; $selectionLength = $null;
	[Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)
	$line = $null; $cursor = $null;
	[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

	if ($selectionStart -ne -1) {
		# Text is selected, wrap it in brackets
		[Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $key.KeyChar + $line.SubString($selectionStart, $selectionLength) + $closeChar)
		[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
	} else {
		# No text is selected, insert a pair
		[Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)$closeChar")
		[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
	}
}

Set-PSReadLineKeyHandler -Key ')', ']', '}' `
						-BriefDescription SmartCloseBraces `
						-LongDescription 'Insert closing brace or skip' `
						-ScriptBlock {
	param($key, $arg)

	$line = $null; $cursor = $null;
	[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
	if ($line[$cursor] -eq $key.KeyChar) {
		[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
	} else {
		[Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)")
	}
}
#endregion Smart Insert/Delete

# Each time you press Alt+', this key handler will change the token
# under or before the cursor. It will cycle through single quotes, double quotes, or
# no quotes each time it is invoked.
Set-PSReadLineKeyHandler -Key "Alt+'" `
						-BriefDescription ToggleQuoteArgument `
						-LongDescription 'Toggle quotes on the argument under the cursor' `
						-ScriptBlock {
	param($key, $arg)

	$ast = $null; $tokens = $null; $errors = $null; $cursor = $null;
	[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)
	$tokenToChange = $null
	foreach ($token in $tokens) {
		$extent = $token.Extent
		if ($extent.StartOffset -le $cursor -and $extent.EndOffset -ge $cursor) {
			$tokenToChange = $token
			# If the cursor is at the end (it's really 1 past the end) of the previous token,
			# we only want to change the previous token if there is no token under the cursor
			if ($extent.EndOffset -eq $cursor -and $foreach.MoveNext()) {
				$nextToken = $foreach.Current
				if ($nextToken.Extent.StartOffset -eq $cursor) {
					$tokenToChange = $nextToken
				}
			}
			break
		}
	}

	if ($tokenToChange -ne $null) {
		$extent = $tokenToChange.Extent
		$tokenText = $extent.Text
		if ($tokenText[0] -eq '"' -and $tokenText[-1] -eq '"') {
			# Switch to no quotes
			$replacement = $tokenText.Substring(1, $tokenText.Length - 2)
		} elseif ($tokenText[0] -eq "'" -and $tokenText[-1] -eq "'") {
			# Switch to double quotes
			$replacement = '"' + $tokenText.Substring(1, $tokenText.Length - 2) + '"'
		} else {
			# Add single quotes
			$replacement = "'" + $tokenText + "'"
		}
		[Microsoft.PowerShell.PSConsoleReadLine]::Replace($extent.StartOffset, $tokenText.Length, $replacement)
	}
}

# This example will replace any aliases on the command line with the resolved commands.
Set-PSReadLineKeyHandler -Key 'Alt+%' `
						-BriefDescription ExpandAliases `
						-LongDescription 'Replace all aliases with the full command' `
						-ScriptBlock {
	param($key, $arg)

	$ast = $null; $tokens = $null; $errors = $null; $cursor = $null;
	[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)

	$startAdjustment = 0
	foreach ($token in $tokens) {
		if ($token.TokenFlags -band [TokenFlags]::CommandName) {
			$alias = $ExecutionContext.InvokeCommand.GetCommand($token.Extent.Text, 'Alias')
			if ($alias -ne $null) {
				$resolvedCommand = $alias.ResolvedCommandName
				if ($resolvedCommand -ne $null) {
					$extent = $token.Extent
					$length = $extent.EndOffset - $extent.StartOffset
					[Microsoft.PowerShell.PSConsoleReadLine]::Replace($extent.StartOffset + $startAdjustment, $length, $resolvedCommand)
					# Our copy of the tokens won't have been updated, so we need to
					# adjust by the difference in length
					$startAdjustment += ($resolvedCommand.Length - $length)
				}
			}
		}
	}
}