{ lib
, symlinkJoin
, writers
, nushell
,
}:

{ name
, text
, modules ? [ ]
, runtimeInputs ? [ ]
, runtimeEnv ? null
,
}:

let
  modulesDrv = symlinkJoin {
    name = "modules";
    paths = modules;
  };

  interpreterArgs = [
    "--no-config-file"
  ]
  ++ (lib.optional (modules != [ ]) "--include-path=${modulesDrv}");

  setEnvWrapperArgs = lib.pipe runtimeEnv [
    (lib.mapAttrsToList (
      name: value: [
        "--set"
        name
        value
      ]
    ))
    lib.flatten
  ];
in
writers.makeScriptWriter
{
  interpreter = "${lib.getExe nushell} ${lib.concatStringsSep " " interpreterArgs}";
  makeWrapperArgs =
    lib.optionals (runtimeInputs != [ ]) [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath runtimeInputs)
    ]
    ++ lib.optionals (runtimeEnv != null) setEnvWrapperArgs;
} "/bin/${name}"
  text
