function select_starship_config
    # Check if we're in the native Linux terminal
    if test "$TERM" = "linux"
        # Use simple text-based config for Linux console
        set -gx STARSHIP_CONFIG ~/.config/starship/fallback.toml
    else
        # Use nerd font config for modern terminals
        set -gx STARSHIP_CONFIG ~/.config/starship/starship.toml
    end
end
