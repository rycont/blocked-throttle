# blocked-throttle

X·인스타그램·클리앙을 **최근 20분 중 10분 이상** 보고 있으면, Zen 브라우저의 네트워크에만 지연을 걸어 재미없게 만듭니다.

차단이 아니라 마찰입니다. 5분에 경고, 10분에 쿨다운, 사용 시간이 줄면 자동 해제.

## 환경

KDE Plasma (Wayland) + Zen Browser (flatpak) + systemd. Arch에서 만들었습니다.
필요한 것: `nft` `tc` `jq` `lz4` `qdbus6` `notify-send` (전부 기본 설치돼 있는 편)

## 설치

```sh
./install.sh
```

root가 필요한 건 `blocked-qos` 하나뿐이고, sudoers로 `on`/`off` 인자만 허용됩니다.

## 어떻게 동작하나

세 가지가 각각 흔치 않은 방법을 씁니다.

**1. 지금 보고 있는 창** — Wayland라 `xdotool`/`wmctrl`이 안 됩니다. KWin에 상주 스크립트를 올려
`windowActivated`와 `captionChanged`를 저널로 흘려보내고, 데몬이 `journalctl -f`로 받습니다. 폴링 없음.

**2. 지금 보고 있는 URL** — Zen의 세션스토어 `recovery.jsonlz4`는 mozlz4(`mozLz40\0` + 크기 4바이트 + raw LZ4 블록)입니다.
앞 12바이트를 LZ4 legacy 프레임 헤더로 바꿔치기하면 파이썬 lz4 모듈 없이 `lz4 -d`로 풀립니다. 약 34ms.

**3. 지연 걸기** — 도메인별 QoS는 SNI든 DNS든 함정이 많습니다. 대신 Zen이 flatpak이라 자기 systemd scope를 갖는 걸
이용해, nftables `socket cgroupv2`로 **Zen에서 나가는 패킷에만** 마크를 찍고 `tc netem`으로 보냅니다.
도메인 판정은 이미 위에서 URL로 했으니 커널이 다시 할 필요가 없습니다.

시간 누적은 전이 로그(`~/.cache/blocked-throttle.ledger`)에 초 단위로 쌓고,
상태 변화는 이벤트로 즉시, 임계 판정은 60초 틱으로 합니다.
아무 일도 안 일어날 때(켜놓고 20분 가만히) 판정하려면 틱이 필요합니다.

## 사용

```sh
blocked-throttle --status   # 현재 URL, 누적 시간, 지연 적용 여부
blocked-throttle --test     # 자가검증 (도메인 매칭, 시간 누적, 레벨 사다리)
sudo /usr/local/sbin/blocked-qos on|off   # 수동으로 걸기/풀기
```

## 조절

`blocked-throttle` 상단:

| 변수 | 기본 | 뜻 |
|---|---|---|
| `WINDOW` | 1200 | 판정 창 (초) |
| `WARN` | 300 | 경고 알림 |
| `THRESHOLD` | 600 | 쿨다운 발동 |
| `RELEASE` | 540 | 해제 (히스테리시스, 경계에서 깜빡이지 않게) |

차단 도메인은 `~/.config/blocked-throttle.list`:

```
# 한 줄에 하나. 서브도메인은 자동 포함.
x.com
twitter.com
instagram.com
clien.net
```

수정하면 **다음 창 전환 때 바로 반영**됩니다. 재시작 불필요. 목록이 비면 아무것도 잡지 않습니다.

세기는 `blocked-qos` 상단 (`sudo -e /usr/local/sbin/blocked-qos`):

| 값 | 체감 |
|---|---|
| `DELAY=1000ms JITTER=300ms LOSS=0%` | 느리지만 참을 만함 |
| `DELAY=2000ms JITTER=800ms LOSS=2%` | 기본값. 무한스크롤이 배치마다 멎고 영상은 못 봄 |
| `DELAY=3000ms JITTER=1500ms LOSS=5%` | 고장으로 느껴져서 역효과 |

지연보다 지터와 손실이 핵심입니다. 균일한 지연은 프리페치가 가려줍니다.

## 알려진 한계

- **유휴 감지 없음.** 화면 켜두고 자리를 비우면 계속 카운트됩니다. KIdleTime DBus로 막을 수 있습니다.
- **인터페이스 전환.** 쿨다운 중 유선↔무선을 바꾸면 지연이 옛 인터페이스에 남습니다. 다음 쿨다운 때 새 인터페이스에 다시 걸립니다.
- **Zen 전체가 느려집니다.** 쿨다운 중엔 작업용 탭도 같이 느려집니다. 브라우저를 닫게 만드는 압력이기도 하지만, 작업 중이면 짜증납니다.
- **URL은 최대 15초 늦습니다.** 세션스토어 기록 주기 탓. 10분 임계에는 무해합니다.
- Zen 외 브라우저는 미지원. `BLOCKED` 옆의 `app.zen_browser.zen`과 `current_url()`의 프로필 경로를 고치면 Firefox 계열은 됩니다.
