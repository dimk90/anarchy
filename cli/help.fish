function help --description "Colorized --help output using bat"
    bat -plhelp --theme TwoDark (eval "$argv --help" 2>&1 | psub)
end
