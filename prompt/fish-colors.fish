# Managed by configure-prompt. Global scope keeps these settings in this file
# instead of adding persistent state to fish_variables.
#
# ANSI color codes:
# https://hexdocs.pm/color_palette/ansi_color_codes.html

# Syntax highlighting
# https://fishshell.com/docs/current/interactive.html#syntax-highlighting-variables
set -g fish_color_normal AAA
set -g fish_color_command 5BF --bold
set -g fish_color_operator 0FB --bold       # ( ), { }, ...
set -g fish_color_param normal              # Disable highlighting
set -g fish_color_autosuggestion 444
set -g fish_color_comment 464 --italic
set -g fish_color_quote BE7                 # "Text"
set -g fish_color_escape 9EC                # "...\n"
set -g fish_color_valid_path --underline
set -g fish_color_error D55
set -g fish_color_end FD6                   # Separators like ; and &
set -g fish_color_redirection FD6           # Like >/dev/null
set -g fish_color_history_current --bold
set -g fish_color_search_match normal       # Disable highlighting

# Pager
# https://fishshell.com/docs/current/interactive.html#pager-color-variables
set -g fish_pager_color_prefix brwhite --bold
set -g fish_pager_color_selected_prefix black
set -g fish_pager_color_completion normal
set -g fish_pager_color_selected_completion black
set -g fish_pager_color_description 555
set -g fish_pager_color_selected_description black
set -g fish_pager_color_selected_background --background=AFA
set -g fish_pager_color_progress black --background=7FF
