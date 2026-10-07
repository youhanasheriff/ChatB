# Validation environment only; containers on macOS do not expose its Bluetooth.
FROM rust:1.85-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgtk-4-dev libdbus-1-dev pkg-config xvfb xauth dbus-x11 python3-dbusmock \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
ENV CARGO_TARGET_DIR=/linux-target
CMD ["bash", "apps/linux/scripts/check.sh"]
