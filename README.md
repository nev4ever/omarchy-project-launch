# Project Launchers

This folder contains project-specific launch scripts for an Omarchy Arch Linux
desktop. Each script is intended to rebuild a full working session for one
project: terminals, tmux sessions, Docker containers, browser tabs, desktop apps,
and file explorers.

The current launchers are:

- `bestconnect.sh` - starts the Bestconnect development workspace.
- `oc.sh` - starts an OC-style development workspace.

Shared launcher code lives in:

- `lib/webdev-launcher.sh` - common web-development workspace behavior.

## Target Environment

These scripts are designed for this local desktop environment:

- OS: Omarchy on Arch Linux
- Window manager: Hyprland
- Terminal: Kitty by default
- Shell: Bash
- Terminal multiplexer: tmux
- Containers: Docker Compose
- Frontend tooling: Node.js/npm where a project needs it
- Browser: Chromium by default
- File manager: Nautilus
- Other apps used by project launchers: Postman, Hey, WhatsApp for Linux

The scripts rely on `hyprctl` to switch Hyprland workspaces and launch windows.
They are not portable to non-Hyprland desktops without changes.

## Purpose

The goal is to launch a complete, repeatable project workspace with one command
or shortcut while keeping workspace 6 and above untouched for developing or
debugging the launcher itself.

When started from an interactive terminal, the launcher detaches itself into a
background process before closing workspaces 1 through 5. This prevents the
cleanup step from killing the terminal that started the launch.

A launcher should be able to:

- close windows on workspaces 1 through 5 before starting
- start required Docker containers
- create or reuse project tmux sessions for Codex, Neovim, and the running
  program
- create multiple tmux windows and panes only in the running-program session
- navigate each terminal or pane to the correct directory
- run project commands such as dev servers, tests, and logs
- open browser windows with project-specific tabs
- open supporting apps such as Postman, email, chat, and file explorers
- place everything on predictable Hyprland workspaces

## Webdev Workspace Model

The intended layout is:

- Workspace 1: three terminals. Left attaches to a single-window Codex tmux
  session, middle attaches to a single-window Neovim tmux session, and right
  attaches to the project tmux session that runs the program.
- Workspace 2: browser for the running web app on the left, a terminal attached
  to the same running-program tmux session in the middle, and Postman on the
  right.
- Workspace 3: Jira/project browser on the left, and a second browser on the
  right with Gmail, Google Drive, Google Calendar, and the project GitHub repo.
- Workspace 4: WhatsApp on the left and Hey on the right, launched as Omarchy
  webapps.
- Workspace 5: two file explorer windows opened at the home directory.
- Workspace 6 and above: never touched by the launcher.

## Deterministic Layout

Opening windows on specific workspaces is possible with Hyprland and `hyprctl`.
Fully deterministic placement and ordering is harder than just launching apps,
because GUI applications may start slowly, reuse existing windows, or change
their window titles/classes after launch.

The launcher selects a layout without changing the applications, tmux sessions,
commands, URLs, or workspace assignments:

- `PL_LAYOUT=desktop` (default): retain the original Hyprland tiling and optional
  managed resizes, suitable for the ultrawide workstation. Existing workstation
  configuration needs no changes.
- `PL_LAYOUT=auto` (opt-in): use the laptop layout when the focused monitor is
  at most 1920 logical pixels wide, otherwise use the desktop layout. Display
  scaling and rotation are taken into account. For example, the Framework's
  2880 × 1920 display at 2× scaling is 1440 logical pixels wide.
- `PL_LAYOUT=laptop`: put the windows on each of workspaces 1 through 5 in a
  native Hyprland tabbed group. Each selected window gets the full workspace
  width. Codex is the initially selected terminal on workspace 1.

Machine layouts are versioned in Git:

- `profiles/desktop.env`: the workstation's original tiling (the default).
- `profiles/framework.env`: the Framework 13's full-width tabbed layout.

Keep the workstation's `.env` as it is. On the Framework only, select its
tracked profile once:

```bash
printf 'framework\n' > .profile
```

Only the selector file `.profile` stays local and gitignored; the actual laptop
settings are tracked in `profiles/framework.env`. A checkout without a selector
continues to use the desktop profile, so pulling these changes on the workstation
does not activate the laptop layout.

You can also select a profile for one launch:

```bash
./oc.sh --profile framework
./bestconnect.sh --profile desktop
```

`--profile` takes precedence over the `PL_PROFILE` environment variable and
the local `.profile` selector. Configuration loads in this order: `.env`, the
selected tracked profile, then `.env.local` for any private machine overrides.
The existing project commands and browser URLs continue to come from `.env`.

For automatic switching when docking the laptop to an ultrawide, change
`PL_LAYOUT=laptop` to `PL_LAYOUT=auto` in `profiles/framework.env`. This affects
only machines selecting the Framework profile. Selection happens at launch
time, so attaching or removing a display takes effect on the next launch. Auto
mode uses the focused monitor. `PL_LAPTOP_MAX_WIDTH` changes its width threshold.

On the laptop, click a group tab or use Omarchy's existing
`Super+Alt+Tab` / `Super+Alt+Shift+Tab` shortcuts to switch windows in the
workspace. Browser tabs inside each browser window remain as configured.
All five workspace assignments stay the same, and workspaces 6 and above remain
untouched. No permanent Hyprland rules or keybindings are added.

Grouping happens after the launch phases. The launcher waits up to 15 seconds
per workspace for slow applications (`PL_LAYOUT_WAIT_ATTEMPTS=60`, checked
every 0.25 seconds). If an app is missing or takes longer, it logs a warning and
groups the windows that are available. Groups are then locked to keep later
unrelated windows separate. Managed resizes apply only to the desktop layout.

For this laptop, reuse a copy of your workstation's private `.env` so its app
commands and account-specific browser URLs stay the same, then override local
project paths in `.env.local`. The private files are not stored in this repository.
The machine must have
the configured terminal and supporting apps installed, just as on the workstation.

If a project needs minor post-launch adjustment while keeping windows managed by
Hyprland, use the optional `MANAGED_RESIZES` array. It calls Hyprland's
`resizewindowpixel` dispatcher, so the window remains tiled:

```bash
MANAGED_RESIZES=(
  "2|initialtitle:^(oc-run-mirror)$|20% 0"
)
```

The format is:

```text
workspace|Hyprland window selector|resize parameters
```

For terminal windows, prefer `initialtitle:` selectors because tmux or the shell
may change the live window title after launch.

For reliable normal tiling, launchers should use a combination of:

- stable window titles where the app supports them
- separate browser windows instead of relying only on tab order
- short waits between launch phases
- Hyprland workspace dispatch commands

Project launchers should prefer deterministic window titles such as
`bc-codex`, `bc-nvim`, `bc-run`, and `bc-run-mirror` so windows can be
identified later.

## Closing Existing Windows

Each project launcher closes existing windows on workspaces 1 through 5 only.
Foreground preflight commands can run first so the launching terminal can still
show prompts. Workspace 6 remains available for editing and debugging the
launcher.

Recommended launch order:

1. Run foreground preflight commands, such as sudo service startup.
2. Detach when launched from an interactive terminal.
3. Close Hyprland windows on workspaces 1 through 5.
4. Reuse existing project tmux sessions by name, unless `PL_RESET_TMUX=1` is
   set.
5. Run project Docker startup commands.
6. Create any missing Codex, Neovim, and running-program tmux sessions.

Avoid blindly killing unrelated desktop windows unless the script is explicitly
intended to reset the whole desktop session.

## Multiple Project Configs

This folder should contain one launcher per project, for example:

- `bestconnect.sh`
- `oc.sh`

Each launcher should define its own configuration at the top of the file:

- tmux session name
- optional Codex and Neovim tmux session names
- terminal command
- browser command
- project directories
- Docker or Docker Compose startup commands
- workspace assignments
- browser URLs
- commands to run in tmux panes
- supporting desktop apps

Keep project-specific values inside the project script unless they are shared by
most launchers.

Current OC behavior is configured by `.env`:

- `OC_ROOT_DIR`, `OC_FRONTEND_DIR`, and `OC_CONFIG_FRONTEND_DIR` select the
  local project directories.
- `OC_CODEX_COMMAND` controls how Codex starts, for example with a specific
  Node version. `OC_CODEX_COMMAND_ENV_FILE` defaults to `oc-backend/.env`;
  the launcher reads its last commented `codex resume <session-token>` command
  and appends that resume token.
- `OC_DOCKER_START_COMMAND` starts local containers.
- `OC_JIRA_URLS`, `OC_APP_URLS`, and `OC_RIGHT_BROWSER_URLS` control browser
  tabs.
- `OC_SERVER_COMMAND`, `OC_BACKEND_COMMAND`, `OC_FRONTEND_COMMAND`, and
  `OC_CONFIG_FRONTEND_COMMAND` control tmux commands.

Current Bestconnect behavior is configured by `.env`:

- `BESTCONNECT_ROOT_DIR` selects the local backend repository.
- `BESTCONNECT_CODEX_COMMAND_ENV_FILE` defaults to the project-root `.env`;
  the launcher reads its commented `codex resume <session-token>` command.
- `BESTCONNECT_FRONTEND_DIR` selects the local Angular frontend repository.
- `BESTCONNECT_FRONTEND_PROXY_CONFIG` points Angular dev server requests at the
  local backend without modifying the frontend repo's tracked proxy file.
- `BESTCONNECT_PREFLIGHT_COMMAND` starts services that may need terminal
  interaction before the launcher detaches, such as nginx.
- `BESTCONNECT_BACKEND_COMMAND` and `BESTCONNECT_FRONTEND_COMMAND` run together
  in the project tmux session.
- `BESTCONNECT_APP_URLS` should point to the local frontend, normally
  `http://localhost:4200`.

Use `.env.example` as the template. The real `.env` file is intentionally
ignored by git because it contains local paths, account-specific URLs, and
private project details.

The shared `webdev` launcher creates these tmux sessions by default:

- `${SESSION}-codex` for Codex
- `${SESSION}-nvim` for Neovim
- `${SESSION}` for the running program

Only `${SESSION}` uses the `TMUX_WINDOWS` array and gets multiple tmux windows
or split panes. The other two are single-window sessions.

The shared `webdev` launcher expects project scripts to define arrays like:

```bash
PREFLIGHT_COMMANDS=(
  "$PROJECT_ROOT|systemctl is-active --quiet nginx || sudo systemctl start nginx"
)

DOCKER_COMMANDS=(
  "$PROJECT_ROOT|docker compose up -d"
)

TMUX_WINDOWS=(
  "server|$PROJECT_ROOT|npm run dev|$PROJECT_ROOT|npm test -- --watch"
)
```

`PREFLIGHT_COMMANDS` run once in the foreground before the launcher detaches.
Use them for commands that may need terminal interaction, such as a sudo
password prompt. `DOCKER_COMMANDS` run after detaching, closing workspaces, and
creating or reusing tmux sessions, so they should not require interactive
input.

The tmux window format is:

```text
window name|top pane directory|top pane command|bottom pane directory|bottom pane command
```

## Launching

Run a project launcher directly from a terminal:

```bash
bash bestconnect.sh
bash oc.sh
```

If the script is executable, it can also be launched as:

```bash
./bestconnect.sh
./oc.sh
```

To make it executable:

```bash
chmod +x bestconnect.sh oc.sh
```

The same command can be attached to an Omarchy/Hyprland keybinding or launched
from an app launcher.

Detached launch output is written to `/tmp/project-launch-<project-id>.log`, for
example `/tmp/project-launch-oc.log`.

By default, existing tmux sessions are reused. To force a fresh set of tmux
sessions for one launch, run:

```bash
PL_RESET_TMUX=1 ./bestconnect.sh
```

## Bestconnect OAuth Mode

Bestconnect local DATEV OAuth uses nginx on `http://localhost` as the registered
redirect target. Switch the local nginx behavior with:

```bash
bin/bestconnect-oauth-mode.sh frontend
bin/bestconnect-oauth-mode.sh postman
bin/bestconnect-oauth-mode.sh status
```

`frontend` mode redirects DATEV back to the local Angular app at
`http://localhost:4200/#/callback`. Use this for full browser login.

`postman` mode proxies DATEV directly to the backend callback at
`http://localhost:3003/auth/callback`. Use this for the old JSON-token browser
response that can be pasted into Postman.

The script writes `/etc/nginx/conf.d/localhost-oauth.conf`, runs `nginx -t`, and
reloads nginx. It uses `sudo`, so run it from a terminal where you can enter
your password.

## Current Notes

`bestconnect.sh` and `oc.sh` both use the shared webdev layout. Future project
types can use another shared launcher, for example a non-web development layout
without Postman or a running-app browser.
