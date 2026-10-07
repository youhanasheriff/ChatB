#!/usr/bin/env bash
# Run only inside an isolated Debian/Ubuntu CI container as root.
set -euo pipefail
package="$(realpath "${1:?Provide the .deb to validate}")"
[[ "$(id -u)" == 0 ]] || { echo 'Use an isolated root-owned CI container.' >&2; exit 1; }
if dpkg-query -W -f='${Status}' bitchat-desktop 2>/dev/null | grep -q 'install ok installed'; then
  echo 'Refusing to replace an existing installation.' >&2; exit 1
fi
[[ "$(dpkg-deb -f "$package" Architecture)" == "$(dpkg --print-architecture)" ]]
useradd --create-home --shell /bin/sh bitchat-package-test
for attempt in 1 2; do
  # Ubuntu's minimal container excludes /usr/share/doc by default. Retain this
  # package's docs so this isolated fixture checks the full desktop payload.
  apt-get -o 'Dpkg::Options::=--path-include=/usr/share/doc/bitchat-desktop/*' \
    install -y --no-install-recommends --reinstall "$package"
  [[ "$(dpkg-query -W -f='${Version}' bitchat-desktop)" == "$(dpkg-deb -f "$package" Version)" ]]
  test -x /usr/bin/bitchat-desktop
  test -f /usr/share/icons/hicolor/scalable/apps/com.bitchat.desktop.linux.svg
  desktop-file-validate /usr/share/applications/com.bitchat.desktop.linux.desktop
  (cd / && md5sum --check /var/lib/dpkg/info/bitchat-desktop.md5sums)
  runuser -u bitchat-package-test -- /usr/bin/bitchat-desktop --version
  timeout 20s runuser -u bitchat-package-test -- dbus-run-session -- xvfb-run -a \
    env GSK_RENDERER=cairo GTK_A11Y=none /usr/bin/bitchat-desktop --smoke-test
  echo "Installed launch / reinstall pass $attempt verified"
done
apt-get purge -y bitchat-desktop
for path in /usr/bin/bitchat-desktop /usr/share/applications/com.bitchat.desktop.linux.desktop \
  /usr/share/icons/hicolor/scalable/apps/com.bitchat.desktop.linux.svg /usr/share/doc/bitchat-desktop; do
  test ! -e "$path"
done
echo 'Dependencies, installed files, unprivileged launch, reinstall and removal verified.'
