{ pkgs, huixDir, ... }:

{
  # Folders open in yazi (programs/yazi/desktop.nix); Thunar stays at hand
  home.packages = with pkgs; [ thunar ];

  xdg.configFile."Thunar/uca.xml".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <actions>
    <action>
    	<icon>utilities-terminal</icon>
    	<name>Open Terminal Here</name>
    	<submenu></submenu>
    	<unique-id>1770663018404627-1</unique-id>
    	<command>kitty --working-directory %f</command>
    	<description>Declarative Thunar action for opening kitty in the selected directory.</description>
    	<range></range>
    	<patterns>*</patterns>
    	<startup-notify/>
    	<directories/>
    </action>
    <action>
    	<icon>edit-paste</icon>
    	<name>Paste as File</name>
    	<submenu></submenu>
    	<unique-id>1770663018404627-2</unique-id>
    	<command>${huixDir}/scripts/paste-as-file.sh %f</command>
    	<description>Paste clipboard text/image as a file into the current folder.</description>
    	<range></range>
    	<patterns>*</patterns>
    	<startup-notify/>
    	<directories/>
    </action>
    </actions>
  '';
}
