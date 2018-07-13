import os, ospaths, osproc, parseopt, sequtils, streams, strutils

type
  BuildInfo = object
    filename: string
    name: string
    author: string
    version: string
    icon: string

    dkpPath: string
    libnxPath: string

    compilerPath: string
    toolsPath: string
    romfsPath: string

    outDir: string
    libs: string
    includes: string

    force: bool
    verbose: bool
    release: bool

    elfLocation: string

    nimCompilerArgs: string


proc execProc(cmd: string, verbose: bool=false): string {.discardable.}=
  result = ""
  var
    p = startProcess(
      cmd,
      options={poStdErrToStdOut, poUsePath, poEvalCommand}
    )

    outp = outputStream(p)
    line = newStringOfCap(120).TaintedString

  if verbose:
    echo "Executing command: " & cmd

  while true:
    if outp.readLine(line):
      if verbose:
        echo line
      result.add(line)
      result.add("\n")
    elif not running(p): break

  var x = p.peekExitCode()
  if x != 0:
    raise newException(
      Exception,
      "Command failed: " & $x &
      "\nCMD: " & $cmd &
      "\nRESULT: " & $result
    )

proc writeVersion() =
  echo "Switch build version $version." % ["version", "0.1.2"]

proc writeHelp() =
  writeVersion()
  echo """
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
  """

proc buildElf(buildInfo: BuildInfo): string =
  echo "Building elf file..."
  var cmd = "nim $args c " &
            "--os:nintendoswitch " & buildInfo.filename.quoteShell

  result = buildInfo.outDir/buildInfo.name & ".elf"

  var args = " --out=" & quoteShell(result)
  args &= " --nimcache=nimcache/" & $buildInfo.name
  if buildInfo.release:
    args &= " -d:release"
  if buildInfo.force:
    args &= " -f"
  if buildInfo.libs != "":
    args &= " --passL='" & buildInfo.libs & "'"
  if buildInfo.includes != "":
    args &= " --passC='" & buildInfo.includes & "'"
  args &= " " & buildInfo.nimCompilerArgs

  cmd = cmd % ["args", args]
  execProc cmd, buildInfo.verbose

proc buildNso(buildInfo: BuildInfo): string =
  let name = buildInfo.name

  result = buildInfo.outDir / name & ".nso"

  var cmd = buildInfo.toolsPath / "elf2nso "
  cmd &= buildInfo.elfLocation & " " & result

  execProc cmd, buildInfo.verbose


proc buildPfs0(buildInfo: BuildInfo): string =
  let nsoPath = buildNso(buildInfo)

  let
    name = buildInfo.name
    outDir = buildInfo.outDir
    toolsPath = buildInfo.toolsPath

  result = outDir / name & ".pfs0"

  createDir outDir & "/exefs"
  copyFile nsoPath, outDir / "exefs/main"
  execProc toolsPath / "build_pfs0 " & outDir / "exefs " & result

proc buildLst(buildInfo: BuildInfo): string =
  let
    name = buildInfo.name
    outDir = buildInfo.outDir
    compDir = buildInfo.compilerPath

  result = outDir / name & ".lst"
  var cmd = compDir / "aarch64-none-elf-gcc-nm " & buildInfo.elfLocation
  cmd &= " > " & result

  execProc cmd, buildInfo.verbose

proc buildNacp(buildInfo: BuildInfo): string =
  let
    name = buildInfo.name
    outDir = buildInfo.outDir
    toolsPath = buildInfo.toolsPath
    author = buildInfo.author
    version = buildInfo.version

  result = outDir / name & ".nacp"

  var cmd = toolsPath / "nacptool --create " & name
  cmd &= " '" & author & "' '" & version & "' "
  cmd &= result

  execProc cmd, buildInfo.verbose

proc buildNro(buildInfo: BuildInfo): string =
  let nacpPath = buildNacp(buildInfo)
  let
    name = buildInfo.name
    outDir = buildInfo.outDir
    toolsPath = buildInfo.toolsPath
    icon = buildInfo.icon
    elfLocation = buildInfo.elfLocation

  result = outDir / name & ".nro"

  var cmd = toolsPath / "elf2nro " & elfLocation & " " & result
  cmd &= " --icon=" & icon & " --nacp=" & nacpPath

  if buildInfo.romfsPath != "":
    cmd &= " --romfsdir=" & buildInfo.romfsPath

  execProc cmd, buildInfo.verbose

proc buildAll(buildInfo: BuildInfo): seq[string] =
  result = @[]
  result.add buildNso(buildInfo)
  result.add buildPfs0(buildInfo)
  result.add buildLst(buildInfo)
  result.add buildNacp(buildInfo)
  result.add buildNro(buildInfo)


proc build(buildType: string, buildInfo: BuildInfo): string =
  echo "Building $#..." % buildType
  case buildType:
    of "all":
      result = buildAll(buildInfo).join("\n")
    of "nro":
      result = buildNro(buildInfo)
    of "nso":
      result = buildNso(buildInfo)
    of "pfs0":
      result = buildPfs0(buildInfo)
    of "nacp":
      result = buildNacp(buildInfo)
    of "lst":
      result = buildLst(buildInfo)

proc sanitizePath(path: string): string =
  path.expandFilename().quoteShell()

proc processArgs() =

  let dkpEnv = "DEVKITPRO"

  var buildInfo = BuildInfo(
    filename: "",
    name: "",
    author: "",
    version: "0.1.0",
    icon: "",

    dkpPath: getEnv(dkpEnv),
    libnxPath: "",

    compilerPath: "",
    toolsPath: "",
    romfsPath: "",

    outDir: "",
    libs: "",
    includes: "",

    force: false,
    verbose: false,
    release: false,

    elfLocation: "",
    nimCompilerArgs: ""
  )

  var buildTypes: seq[string] = @[]


  for kind, key, val in getopt():
    case kind
    of cmdArgument:
      buildInfo.filename = key.sanitizePath()
    of cmdLongOption, cmdShortOption:
      case key
      of "devkitProPath", "d":
        buildInfo.dkpPath = val
        putEnv(dkpEnv, val)
      of "devkitCompilerPath", "c":
        buildInfo.compilerPath = val
      of "libnxPath", "x":
        buildInfo.libnxPath = val.sanitizePath()
      of "output", "o":
        buildInfo.outDir = val.sanitizePath()
      of "tools", "t":
        buildInfo.toolsPath = val.sanitizePath()
      of "build", "b":
        buildTypes.add(val)
      of "libs", "l":
        buildInfo.libs = val
      of "includes", "i":
        buildInfo.includes = val
      of "name", "n":
        buildInfo.name = val
      of "icon", "p":
        buildInfo.icon = val.sanitizePath()
      of "version", "v":
        buildInfo.version = val
      of "author", "a":
        buildInfo.author = val
      of "forceBuild", "f":
        buildInfo.force = true
      of "release", "r":
        buildInfo.release = true
      of "romfsPath", "romfsDir", "q":
        buildInfo.romfsPath = val.sanitizePath()
      of "nimCompilerArgs":
        buildInfo.nimCompilerArgs = val
      of "verbose":
        buildInfo.verbose = true
      of "help", "h":
        writeHelp()
        quit(0)
      else:
        writeHelp()
        echo "Error invalid argument: \"" & key & "\""
        quit(1)
    of cmdEnd: assert(false) # cannot happen

  if buildInfo.filename == "":
    writeHelp()
    echo "filename argument was expected!"
    quit(1)

  if buildTypes.len == 0:
    buildTypes.add("all")

  if buildInfo.name == "":
    buildInfo.name = buildInfo.filename.splitFile().name

  if buildInfo.outDir == "":
    buildInfo.outDir = "build" / buildInfo.name

  if not dirExists buildInfo.outDir:
    createDir buildInfo.outDir
    buildInfo.outDir = expandFilename(buildInfo.outDir)

  if buildInfo.dkpPath == "":
    buildInfo.dkpPath = getEnv(dkpEnv, "").sanitizePath()
    let exists = buildInfo.dkpPath.dirExists()
    if buildInfo.dkpPath == "" and not dkpEnv.existsEnv() and exists:
      writeHelp()
      raise newException(
        Exception,
        dkpEnv & " environment var must be set and be an existing path or " &
        "--devkitProPath must be set in the command line arguments."
      )

  if buildInfo.libnxPath == "":
    buildInfo.libnxPath = buildInfo.dkpPath / "libnx"
    if not buildInfo.libnxPath.dirExists():
      try:
        buildInfo.libnxPath = execProc("nimble path libnx") / "src/libnx/wrapper/nx"
      except Exception:
        raise newException(Exception,
          "Could not find a suitable libnx install. " &
          "Make sure libnx is installed in $DEVKITPRO/libnx or " &
          "you have --libnxPath set in the command line arguments.")

  buildInfo.includes &= getEnv("SWITCH_INCLUDES") & " -I" & buildInfo.libnxPath / "include"
  buildInfo.libs &= getEnv("SWITCH_LIBS")
  buildInfo.libs &= " -specs=" & buildInfo.libnxPath / "switch.specs"
  buildInfo.libs &= " -L" & buildInfo.libnxPath / "lib -lnx"

  if buildInfo.icon == "":
    buildInfo.icon = buildInfo.libnxPath / "default_icon.jpg"

  if buildInfo.compilerPath == "":
    buildInfo.compilerPath = buildInfo.dkpPath / "devkitA64/bin"

  if buildInfo.toolsPath == "":
    buildInfo.toolsPath = buildInfo.dkpPath / "tools/bin"

  echo "Building: $#..." % buildInfo.filename

  buildInfo.elfLocation = buildElf(buildInfo)

  # Build the files
  for buildType in buildTypes:
    let path = build(buildType, buildInfo)
    echo "\nBuilt:"
    echo path
  echo ""

proc main() =
  processArgs()

when isMainModule:
  main()
