<div align="center">

<img src="../../assets/say-sketch2.webp" alt="say sketch" width="280"/>

</div>

# Programs

[![huix](https://img.shields.io/badge/huix-up-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../README.md)
[![home-manager](https://img.shields.io/badge/home--manager-user_layer-5E81AC?style=for-the-badge)](../README.md)
[![nixvim](https://img.shields.io/badge/nixvim-neovim-019733?style=for-the-badge&logo=neovim&logoColor=white)](nixvim/README.md)
[![yazi](https://img.shields.io/badge/yazi-files-FFC107?style=for-the-badge)](yazi/README.md)

The programs that make the user environment comfortable live here, each shaped around a familiar way of working

Among them are the editor [Nixvim](nixvim/README.md), the file manager [Yazi](yazi/README.md), the command-line tools and the graphical applications

Pi takes its MCP servers and its skills from the shared lists of the agents. A server and a skill are declared once, beside the tool they belong to, and nothing is registered by hand. The calendar, the search for papers, Ghidra and the creative applications arrive this way. The skills of their own repositories come as flake inputs, and each host takes only the ones it needs

Inside pi the tools are split into packages that switch off: `huix` for development and the system configuration, `reversing` for reverse engineering, `research` for papers and documentation, `creative` for video, sound and 3D, `design` for slides, canvases, design systems, dashboards and films, `remote` for communication and the control of devices. `pi config` switches a package off with its skills and its MCP servers, and `/mcp` switches off one server

The stock Home Manager module carries the base settings of pi. The preferences of the interface stay editable: they survive the runs, and Nix changes them only when the declarative source changes. The keys and the Codex login live apart from the Nix configuration

The extensions add background subagents, the link between sessions, side conversations and an automatic review of actions by a separate model. The OpenRouter routes are limited to the chosen hosts with Zero Data Retention and with training on the requests forbidden

The `/hoster` command picks the host of the current OpenRouter model from the allowed list, or returns the automatic choice. It shows the price, the context and the quantisation from the OpenRouter catalogue, and an estimate of the cost from the token spend of the session. The preference is kept locally for each model, and the route of the auto-mode classifier stays independent

`reversing/` holds Ghidra with ReVa, and REA with its own MCP and its own skill for the study of applications. REA uses Ghidra for a headless analysis, and reads the formats it supports without starting the graphical editor too

The creative applications are gathered in `creative/`: Kdenlive with MCP and the Anatomy, Remotion and sound-layer skills, Blender with MCP, Audacity with MCP, FreeCAD with MCP, rea-video, a skill with a CLI that takes a finished film apart frame by frame and returns a plan to shoot it again, and compress-video, which compresses a video through FFmpeg for the chosen codecs and CRF. The video editor lets the manual cutting continue after the agent, and the sound tools pick effects, mix the tracks and check the result

`design/` holds baoyu-design: the artifact types of claude.ai as local skills with their editors — a slide deck, a canvas, a design system, a dashboard and a film. The agent writes the files into the project folder, the editor opens beside it and saves the edits to the same place

A few tools grew into projects of their own; the root [README](../../README.md#extracted-into-their-own-repositories) links them all
