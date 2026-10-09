# The public part of a Forgejo runner's secret, made from the runner's name. A secret is 40 hex
# characters, and Forgejo takes the first 16 as the runner's UUID, which it shows to anyone who
# administers it. So those 16 come from the name, and only the last 24 are secret and live in
# sops. The forge that registers a runner and the runner that connects both read this file
lib: name:
let
  prefix = builtins.substring 0 16 (builtins.hashString "sha256" name);
  # The UUID holds the 16 bytes of the prefix as text: each character is its ASCII code in hex
  hex = lib.concatMapStrings (char: lib.toLower (lib.toHexString (lib.strings.charToInt char))) (
    lib.stringToCharacters prefix
  );
  part = start: length: builtins.substring start length hex;
in
{
  inherit prefix;
  uuid = "${part 0 8}-${part 8 4}-${part 12 4}-${part 16 4}-${part 20 12}";
}
