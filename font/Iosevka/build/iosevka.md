# Iosevka

Custom build of [Iosevka](https://github.com/be5invis/Iosevka) font.

> [!NOTE]
>  - https://typeof.net/Iosevka/customizer  
>  - https://github.com/be5invis/Iosevka/blob/main/doc/custom-build.md


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
    curl -o private-build-plans.toml "https://github.com/dimk90/anarchy/font/Iosevka/build/private-build-plans.toml"
    ```

- Build font:
    ```shell
    npm run build -- webfont::IosevkaCode --jCmd=4
    ```

    ```shell
    npm run build -- webfont::IosevkaText --jCmd=4
    ```

    > [!TIP]
    > Verbose build:
    > ```shell
    > npm run build --loglevel verbose -- webfont::IosevkaCustom --jCmd=1 --verbosity 100
    > ```


###  TTC Font Package

Packages are useful for system-wide installation.

```shell
uv tool install afdko
```

```shell
otf2otc -o dist/IosevkaCode/IosevkaCode.ttc dist/IosevkaCode/TTF/*.ttf
```

```shell
otf2otc -o dist/IosevkaTerm/IosevkaTerm.ttc dist/IosevkaTerm/TTF/*.ttf
```
