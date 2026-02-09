attrs:
builtins.concatStringsSep "\n" (
  builtins.attrValues (
    builtins.mapAttrs (
      k: v:
      if builtins.isList v then
        "${builtins.concatStringsSep "\n" (map (x: "${toString k} = ${toString x}") v)}"
      else
        "${toString k} = ${toString v}"
    ) attrs
  )
)
