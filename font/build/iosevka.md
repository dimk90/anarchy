# Iosevka

Custom build of [Iosevka](https://github.com/be5invis/Iosevka) font.

> [!Note] Iosevka Customizer
> https://typeof.net/Iosevka/customizer  
> https://github.com/be5invis/Iosevka/blob/main/doc/custom-build.md


## Build

- Install dependencies:
    ```shell
    sudo pacman -S npm woff2
    ```

    ```shell
    yay -S ttfautohint
    ```

- Clone iosevka repo:
    ```shell
    git clone --depth 1 https://github.com/be5invis/Iosevka.git 
    ```

- Install npm dependencies:
    ```shell
    cd iosevka && npm install
    ```

- Get custom config:
    ```shell
    curl -o private-build-plans.toml "https://github.com/dimk90/anarchy/raw/refs/heads/main/font/build/private-build-plans.toml"
    ```

- Build font:
    ```shell
    npm run build -- webfont-unhinted::IosevkaCustom --jCmd=4
    ```

    > [!Tip] Verbose build
    > ```shell
    > npm run build --loglevel verbose -- webfont-unhinted::IosevkaCustom --jCmd=1 --verbosity 100
    > ```
