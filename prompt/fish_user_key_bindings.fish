#
# Managed by configure-prompt. Text-editor-style selection for fish's default
# (emacs) key bindings: shift+motion selects, plain motion clears, typing or
# pasting replaces the selection, backspace/delete removes it.
#
# TEMPORARY. fish 4.8 ships the selection primitives (begin-selection,
# kill-selection, `commandline --current-selection`, fish_color_selection
# highlighting) but binds none of them outside vi visual mode. Upstream PR
# fish-shell#12815 adds exactly this to the default bindings, so drop this file
# and fish_install_key_bindings in configure-prompt once it reaches a release.
#
# What used to live here - ctrl-arrow word motions and ctrl-backspace/delete
# word kills - is gone: fish 4.x already binds all four as presets.
#

# The functions below track a live selection through $__anarchy_selection_active
# (set means "selecting"). fish cannot be asked whether a selection is active,
# and begin-selection restarts the selection instead of extending it, so the
# state has to be kept here.

function __anarchy_selection_extend --description 'Extend the selection over the given motion, starting one if needed'
    if not set -q __anarchy_selection_active
        commandline -f begin-selection
        set -g __anarchy_selection_active
    end
    commandline -f $argv
end

function __anarchy_selection_clear --description 'Drop the selection, keeping the text. False when nothing was selected'
    set -q __anarchy_selection_active; or return 1
    set -e __anarchy_selection_active
    commandline -f end-selection
end

function __anarchy_selection_kill --description 'Delete the selected text to the killring. False when nothing was selected'
    set -q __anarchy_selection_active; or return 1
    set -e __anarchy_selection_active
    commandline -f kill-selection end-selection
end

function __anarchy_selection_move --description 'Clear the selection, then run the given motion'
    __anarchy_selection_clear
    commandline -f $argv
end

# A marker left over from the previous command line would make the next
# shift+motion extend a selection anchored in a buffer that no longer exists.
function __anarchy_selection_reset --on-event fish_prompt --description 'Forget the selection between command lines'
    set -e __anarchy_selection_active
end

function fish_user_key_bindings
    # Shift+motion extends the selection. This shadows fish's preset
    # shift-left/shift-right, which move by bigword.
    bind shift-left       '__anarchy_selection_extend backward-char'
    bind shift-right      '__anarchy_selection_extend forward-char'
    bind shift-up         '__anarchy_selection_extend up-line'
    bind shift-down       '__anarchy_selection_extend down-line'
    bind shift-home       '__anarchy_selection_extend beginning-of-line'
    bind shift-end        '__anarchy_selection_extend end-of-line'
    bind ctrl-shift-left  '__anarchy_selection_extend backward-word'
    bind ctrl-shift-right '__anarchy_selection_extend forward-word'

    # Plain motion clears the selection. Every motion fish binds by default
    # needs an entry here, or the highlight lingers after the cursor leaves it.
    # The presets pick token motions inside macOS Terminal, which never applies.
    bind left       '__anarchy_selection_move backward-char'
    bind right      '__anarchy_selection_move forward-char'
    bind up         '__anarchy_selection_move up-or-search'
    bind down       '__anarchy_selection_move down-or-search'
    bind home       '__anarchy_selection_move beginning-of-line'
    bind end        '__anarchy_selection_move end-of-line'
    bind ctrl-left  '__anarchy_selection_move backward-word'
    bind ctrl-right '__anarchy_selection_move forward-word'
    bind alt-left   '__anarchy_selection_move prevd-or-backward-token'
    bind alt-right  '__anarchy_selection_move nextd-or-forward-token'
    bind ctrl-a     '__anarchy_selection_move beginning-of-line'
    bind ctrl-e     '__anarchy_selection_move end-of-line'
    bind ctrl-b     '__anarchy_selection_move backward-char'
    bind ctrl-f     '__anarchy_selection_move forward-char'
    bind ctrl-p     '__anarchy_selection_move up-or-search'
    bind ctrl-n     '__anarchy_selection_move down-or-search'
    bind alt-b      '__anarchy_selection_move prevd-or-backward-word'
    bind alt-f      '__anarchy_selection_move nextd-or-forward-word'
    bind 'alt-<'    '__anarchy_selection_move beginning-of-buffer'
    bind 'alt->'    '__anarchy_selection_move end-of-buffer'

    # Backspace and delete remove the selection when there is one, and otherwise
    # keep doing what fish binds them to.
    bind backspace       '__anarchy_selection_kill; or commandline -f backward-delete-char'
    bind ctrl-h          '__anarchy_selection_kill; or commandline -f backward-delete-char'
    bind shift-backspace '__anarchy_selection_kill; or commandline -f backward-delete-char'
    bind ctrl-backspace  '__anarchy_selection_kill; or commandline -f backward-kill-word'
    bind alt-backspace   '__anarchy_selection_kill; or commandline -f backward-kill-token'
    bind delete          '__anarchy_selection_kill; or commandline -f delete-char'
    bind ctrl-delete     '__anarchy_selection_kill; or commandline -f kill-word'
    bind alt-delete      '__anarchy_selection_kill; or commandline -f kill-token'

    # Typing replaces the selection. The empty key is fish's catch-all for
    # anything without its own binding, which is every ordinary character; the
    # punctuation below needs its own binding because it also expands
    # abbreviations. ctrl-v is fish_clipboard_paste, ctrl-x copies the
    # selection on its own already.
    bind '' __anarchy_selection_kill self-insert
    for key in space ';' '|' '&' '>' '<' ')'
        bind $key __anarchy_selection_kill self-insert expand-abbr
    end
    bind ctrl-v '__anarchy_selection_kill; fish_clipboard_paste'
end
