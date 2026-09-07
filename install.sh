#!/usr/bin/env bash
# 유저 파트는 그냥 설치, root 파트는 sudo. 재실행해도 안전.
set -eu
cd "$(dirname "$0")"

install -Dm755 blocked-throttle ~/.local/bin/blocked-throttle
install -Dm644 blocked-throttle.service ~/.config/systemd/user/blocked-throttle.service
[[ -e ~/.config/blocked-throttle.list ]] || install -Dm644 blocklist ~/.config/blocked-throttle.list

sudo install -o root -g root -m 755 blocked-qos /usr/local/sbin/blocked-qos
sed "s/^rycont /$USER /" blocked-qos.sudoers > /tmp/blocked-qos.sudoers.$$
sudo install -o root -g root -m 440 /tmp/blocked-qos.sudoers.$$ /etc/sudoers.d/blocked-qos
rm -f /tmp/blocked-qos.sudoers.$$
sudo visudo -c >/dev/null

systemctl --user daemon-reload
systemctl --user enable --now blocked-throttle.service
~/.local/bin/blocked-throttle --test
echo "설치 완료. 상태: blocked-throttle --status"
