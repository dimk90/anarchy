select_starship_config() {
    # Check if we're in the native Linux terminal
    if [ "$TERM" = "linux" ]; then
        # Use simple text-based config for Linux console
        export STARSHIP_CONFIG=~/.config/starship/fallback.toml
    else
        # Use selected theme for modern terminals
        export STARSHIP_CONFIG=~/.config/starship/starship.toml
    fi
}
