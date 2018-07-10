# switch-build
Build switch homebrew apps the easy way

# Options

```bash
$ switch_build --help
Switch build version 0.1.2.
::
    switch-build [options] project-file.nim

Note:
  $DKP refers to the devkitpro path, set either by env vars or
  the command line options.

Options:
  -f, --forceBuild          Force compilation of files
  -r, --release             Compile in release mode (no stack traces, more efficient)
  --verbose                 Stream output of compilation tasks
  -x, --libnxPath:PATH      The path where your libnx libraries live. (default is
                            $DKP/libnx). Useful for development of custom libnx
                            features
  -d, --devkitProPath:PATH  Devkitpro installation path for switch-build.
                            Required if DEVKITPRO environment var is unset
  -c, --devkitCompilerPath:PATH
                            The path where the binaries for the devkitpro
                            compiler lives. (defaults to "$DKP/devkitA64/bin/")
  -t, --tools:PATH          The devkitpro tools (defaults to "$DKP/tools/bin")
  -o, --output:PATH         Output files in a specified directory (defaults to "build")
  -b, --build:TYPE          The type of output file you want (defaults to "all")
                            and can be specified multiple times.
                            TYPE is one of: "all", "nro", "nso", "pfs0", "nacp",
                            or "lst"
  -l, --libs:STR            Additional linker args to pass to the compiler.
                            Ex: --libs="-lsdl -Lpath/to/lib"

  -i, --includes:STR        Additional includes to pass to the compiler
                            Ex: --includes="-Ipath/to/include -Ipath/to/another/include"
  -n, --name:STR            The output file name to use. (defaults to input file name)
  -a, --author:STR          Sets the author name for the generate NRO and NACP file
  -v, --version:STR         Sets the version information for the generated NRO and NACP
                            file
  -q, --romfsPath:PATH      Path to use to build in a romfs image
  -p, --icon:PATH           Sets the icon to use for the generated NRO and NACP
                            (defaults to "$DKP/libnx/default_icon.jpg)
  --nimCompilerArgs:STR     Args to pass to the nim compiler
  -h, --help                show this help

Note, single letter options that take an argument require a colon. E.g. -p:PATH.
```
