# switch-build
Build switch homebrew apps the easy way.

# Install prerequisites

You need the latest devel Nim compiler with Nintendo Switch support and you need [nim-libnx](https://github.com/jyapayne/nim-libnx) in order to compile (see examples in the libnx.nimble file).

In order for switch-build to work, you'll need DevkitPro and you'll need to modify some environment variables if you're on Windows.

DevkitPro can be installed via this links: [Mac and Linux](https://github.com/devkitPro/pacman/releases) or [Windows](https://github.com/devkitPro/installer/releases). Install with the Switch development support.

Once you have DevkitPro installed, the DEVKITPRO environment variable must exist and it must point to a valid directory. This isn't an issue on Unix platforms, but on Windows it's a bit more finicky with the default installer.

On Unix platforms (Mac/Linux), simply add:

```bash
export DEVKITPRO="/path/to/devkitpro/root"
# Default is "/opt/devkitpro"
```

to your `.bashrc` or similar shell/login init script.

On Windows, the DevkitPro installer will set environment variables for you, but they will be invalid from a default cmd.exe or powershell instance. You'll need to edit the DevkitPro environment variable to be a valid path. Change it from:

```bash
DEVKITPRO: /opt/devkitpro
```

to something like:

```bash
DEVKITPRO: C:\devkitPro
```

Or where ever you installed it. Once that is set, everything should work fine in Windows.

# Install

Simply install the latest devel Nim compiler and the Nim tools (with the nimble package manager) and run:

```bash
nimble install switch_build
```

# Usage

Basic usage:

```bash
switch_build --author="My Name" --version="1.0.0" examples/helloworld/helloworld.nim
```

See [here](https://github.com/jyapayne/nim-libnx/blob/master/libnx.nimble#L27) for more examples. Also run:

```bash
switch_build --help
```

for more options and configuration.

# Options

```bash
$ switch_build --help
Switch build version 0.1.3
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
  -S, --staticLib           Build static library ("*.a")
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
