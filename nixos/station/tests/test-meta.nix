{ lib, description }:
# The test's meta declares neither field, and the derivation takes its meta from the option
# alone; a second declaration of the submodule adds them
{
  options.meta = lib.mkOption {
    type = lib.types.submodule {
      options.description = lib.mkOption { type = lib.types.str; };
      options.license = lib.mkOption { type = lib.types.attrs; };
    };
  };
  config.meta = {
    inherit description;
    license = lib.licenses.mit;
  };
}
