# MediaManage - The beyond overkill tool to manage a video library
Has this been done before? Probably. I couldn't find anything, but then again I didn't look very hard.

## Use Case and Features

MediaManage is a server-based app to watch over your media files. For my use case, I had a wide mix of av1, h264, h265, webm, and other exoticaly encoded files I wanted to standardize on h265 for use with Jellyfin (or plex, whatever). For some reason, a bunch of these files were corrupt and missing keyframes. I run MediaManage on my home server, pointed at the share directories. Some features include:

- Automatic detection of broken (missing keyframes) media files
- Automatic detection of video codec and effective bitrates*
- Caching of metadata to avoid rescanning over network drives
- One-click re-encoding to preferred type with failure detection, tempfiles, and queuing

## AI Disclosure
Minimal AI was used on this project. AI did/assisted the following:

1) Styling of the HTML file (I don't have the patience for CSS in 2026), generation of the favicon and icons
2) Code review and "make it more idiomatic" for my `if-else-if` c-style algorithms (I'm new to Elixir)
3) Design practices for writing tests and config files (ibid)

## Support and Maintenance

This project may die once I finish it. I mean I'll run it locally and update as I need to for myself, but probably won't include a ton of features I'm not going to use (mainly other codecs, and maybe scheduled encodings). I will, however, accept patches adding these things.

## Supported options

All options are passed via environment variables to enable use in docker. Developers or those running from source can also edit `config/test.dev` or `config/prod.dev`

|Environment Variable|Config Atom|Default (prod)|Purpose|Format|
|---|---|---|---|---
|CONCURRENCY|:max_concurrency|:infinity|Max concurrent ffmpeg tasks|Integer, or :infinity|
|ENCODING|:encode_opts|{ :hevc, "medium", 24 }|Sets output options for the ffmpeg encoder|Tuple, { codec, _, _, _...}. Length depends on codec. See ffmpeg_opts_from_encoding.
|CACHEPATH|:cache_path|/tmp/mediamanage_cache|Sets the cache path|Path, or "" to disable disk caching
|IP|:listen_ip|:any|Listen IP for the server|IP address or "any" or "local"
|PORT|:http_port|4000|HTTP port|Integer 1-65535
|ASSUME_OK|:assume_ok|nil|If supplied, do not try to decode media files to test if valid\*\*|Any nonnil-value
|WORKDIR|:workdir|:nil|Place to store in-progress transcode files, perhaps if there's a system scratchdisk|Path
|LOGLEVEL|:level|:warning|Log level|Valid log level string (error/warning/info/debug)


** - This speeds up metadata scans by multiple orders of magnitude but lead to ffmpeg exploding later for no reason.

## Building (docker and otherwise)
To build the docker container, run `docker build -t mediamanage .`. This produces an image "mediamanage", which can be run as usual with `docker run -d mediamanage`, passing in any environment variables as required. Port selection can be done at the docker level or by passing in the PORT env var.

To make a release suitable for running outside of docker, use `MIX_ENV=prod mix compile; MIX_ENV=prod mix release`. [This doesn't work on Fedora](https://elixirforum.com/t/getting-ssl-error-when-running-mix-release/73692/3), so hasn't been tested. You can also use the docker build container with `docker build --target build -t mm_build .`, then run it with `docker run -v ./out:/out mm_build`, which should copy an built tar.gz file to the `out` directory.

## Ongoing to-do

1. Support more encoding outputs (mostly AV1)
2. Start with type hints on some key functions, to enable compiler warnings
3. Handle graceful termination - Figure out why terminate() isn't running
4. Track dirty flag so cache is only written out if necessary
999. Anything else tagged `#TODO` in the code!

## Development

1) Clone the repository
2) Install dependencies with `mix deps.get`
3) Initialize the test assets with `mix assets.download`
4) Run with `iex --dbg pry -S mix` (development) or `mix run --no-halt`

### Feedback

As an elixir novice, feedback would be loved <3. Please let me know of more idiomatic ways to do things, design patterns I'm not using, and improvements I could make. I <3 open source!