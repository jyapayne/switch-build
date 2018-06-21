# switch-build
Build switch homebrew apps the easy way

# Options

```bash
$ switch_build --help

  switch-build [options] project-file.nim

Options:
  -d, --devkitProPath:PATH  devkitpro installation path for switch-build.
                            Required if DEVKITPRO environment var is unset
  -c, --devkitCompilerPath:PATH
                            the path where the binaries for the devkitpro
                            compiler lives. (defaults to "$DKP/devkitA64/bin/")
  -t, --tools:PATH          the devkitpro tools (defaults to "$DKP/tools/bin")
  -o, --output:PATH         output files in a specified directory (defaults to "build")
  -b, --build:TYPE          the type of output file you want (defaults to "all")
                            and can be specified multiple times.
                            TYPE is one of: "all", "nro", "nso", "pfs0", "nacp",
                            or "lst"
  -l, --libs:STR            additional linker args to pass to the compiler.
                            Ex: --libs="-lsdl -Lpath/to/lib"

  -i, --includes:STR        additional includes to pass to the compiler
                            Ex: --includes="-Ipath/to/include -Ipath/to/another/include"
  -n, --name:STR            the output file name to use. (defaults to input file name)
  -a, --author:STR          sets the author name for the generate NRO and NACP file
  -v, --version:STR         sets the version information for the generated NRO and NACP
                            file
  -p, --icon:PATH           sets the icon to use for the generated NRO and NACP
                            (defaults to "$DKP/libnx/default_icon.jpg)
  -h, --help                show this help

Note, single letter options that take an argument require a colon. E.g. -p:PATH.
```
