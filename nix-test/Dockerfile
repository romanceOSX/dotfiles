# Test the Home Manager config with FULL activation in a throwaway Debian
# container. Nothing here touches your real machine — build it, poke at it,
# `docker rm` it.
#
# It clones the COMMITTED branch from GitHub (not your local working tree), so
# it tests exactly what another machine would pull. Push your changes first if
# you want them included.
#
# Runs NATIVELY: the base image is your host arch, and the flake's linux host
# (`romance@debian`, committed as x86_64-linux) is rewritten to the build arch
# (e.g. aarch64-linux on Apple Silicon) so there's no QEMU emulation — fast, no
# platform-mismatch warning. The config is identical; only the system double
# changes.
#
#   docker build -t hm-test ./nix-test
#   docker run --rm -it hm-test
#
# Test a different branch/host:
#   docker build --build-arg REF=my-branch --build-arg HM_HOST=romance@wsl -t hm-test ./nix-test

FROM debian:bookworm-slim

ARG REPO=https://github.com/romanceOSX/dotfiles.git
ARG REF=nix-home-manager
ARG HM_HOST=romance@debian

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# Base tooling for the Nix installer + clone
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl git xz-utils ca-certificates sudo procps \
    && rm -rf /var/lib/apt/lists/*

# Match the flake's host exactly: user `romance`, home `/home/romance`.
# (home-manager asserts the activating user/home match the config.)
RUN useradd --create-home --shell /bin/bash romance \
    && echo 'romance ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/romance \
    && install -d -o romance -g romance -m 0755 /nix

# Global Nix config, read even by the installer's first build. `sandbox`/
# `filter-syscalls` are off because Nix's seccomp BPF sandbox can't load under
# QEMU emulation (x86_64 on an arm64 host) — fine for a throwaway test box.
RUN mkdir -p /etc/nix && printf '%s\n' \
        'experimental-features = nix-command flakes' \
        'sandbox = false' \
        'filter-syscalls = false' \
        'http2 = false' \
        'download-attempts = 5' \
    > /etc/nix/nix.conf

USER romance
WORKDIR /home/romance
ENV USER=romance HOME=/home/romance

# 1. Install Nix (single-user / --no-daemon works without systemd in a container).
#    Flakes + the sandbox-off settings come from /etc/nix/nix.conf above.
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

# 2. Clone the committed config, then rewrite the linux host's system double to
#    the build architecture so activation builds NATIVELY (no emulation).
#    On x86_64 this is a no-op; on aarch64 it flips x86_64-linux -> aarch64-linux.
RUN git clone --branch "$REF" --depth 1 "$REPO" ~/git/dotfiles \
    && sed -i "s/x86_64-linux/$(uname -m)-linux/g" ~/git/dotfiles/flake.nix

# 3. FULL activation — the real `home-manager switch` (-b backup so any base
#    files Debian ships get moved aside instead of erroring).
RUN . ~/.nix-profile/etc/profile.d/nix.sh \
    && cd ~/git/dotfiles \
    && nix run home-manager/master -- switch -b backup --flake ".#${HM_HOST}"

# Drop into the activated, themed zsh on `docker run`.
COPY --chown=romance:romance entrypoint.sh /home/romance/entrypoint.sh
RUN chmod +x /home/romance/entrypoint.sh
ENTRYPOINT ["/home/romance/entrypoint.sh"]
