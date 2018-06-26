import os, ospaths, osproc, parseopt, sequtils, streams, strutils

type
  BuildInfo = object
    filename: string
    name: string
    author: string
    version: string
    icon: string

    dkpPath: string

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
  echo "Switch build version $version." % ["version", "0.1.0"]

proc writeHelp() =
  writeVersion()
  echo """
::
    switch-build [options] project-file.nim

Options:
  -f, --forceBuild          force compilation of files
  -r, --release             compile in release mode (no stack traces, more efficient)
  --verbose                 Stream output of compilation tasks
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
  -q, --romfsPath:PATH      Path to use to build in a romfs image
  -p, --icon:PATH           sets the icon to use for the generated NRO and NACP
                            (defaults to "$DKP/libnx/default_icon.jpg)
  -h, --help                show this help

Note, single letter options that take an argument require a colon. E.g. -p:PATH.
  """

proc buildElf(buildInfo: BuildInfo): string =
  echo "Building elf file..."
  var cmd = "nim $args c " &
            "--os:nintendoswitch " & buildInfo.filename.quoteShell

  var args = ""
  if buildInfo.release:
    args &= " -d:release"
  if buildInfo.force:
    args &= " -f"
  if buildInfo.libs != "":
    args &= " --passL='" & buildInfo.libs & "'"
  if buildInfo.includes != "":
    args &= " --passC='" & buildInfo.includes & "'"

  cmd = cmd % ["args", args]

  execProc cmd, buildInfo.verbose

  result = buildInfo.filename.splitFile().dir / buildInfo.name & ".elf"

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

    compilerPath: "",
    toolsPath: "",
    romfsPath: "",

    outDir: "",
    libs: "",
    includes: "",

    force: false,
    verbose: false,
    release: false,

    elfLocation: ""
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
    # no filename has been given, so we show the help:
    writeHelp()
    quit(1)

  if buildTypes.len == 0:
    buildTypes.add("all")

  if buildInfo.name == "":
    buildInfo.name = buildInfo.filename.splitFile().name

  if buildInfo.outDir == "":
    buildInfo.outDir = "build"

  if not dirExists buildInfo.outDir:
    createDir buildInfo.outDir
    buildInfo.outDir = expandFilename(buildInfo.outDir)

  if buildInfo.dkpPath == "":
    buildInfo.dkpPath = getEnv(dkpEnv, "").sanitizePath()
    if buildInfo.dkpPath == "" and not dkpEnv.existsEnv():
      writeHelp()
      raise newException(Exception, dkpEnv & " path must be set!")

  if buildInfo.icon == "":
    buildInfo.icon = buildInfo.dkpPath / "libnx/default_icon.jpg"

  if buildInfo.compilerPath == "":
    buildInfo.compilerPath = buildInfo.dkpPath / "devkitA64/bin"

  if buildInfo.toolsPath == "":
    buildInfo.toolsPath = buildInfo.dkpPath / "tools/bin"


  putEnv("SWITCH_LIBS", getEnv("SWITCH_LIBS") & " " & buildInfo.libs)
  putEnv("SWITCH_INCLUDES", getEnv("SWITCH_INCLUDES") & " " & buildInfo.includes)

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
