# Linux Troubleshooting

제공된 `agent-leak-app`을 Linux에서 실행하고 메모리 누수, CPU 과점유, 교착상태를 관측하여 증거 기반 장애 보고서 3건을 작성하는 교육 미션입니다.

실행·관제 도구와 [OOM 보고서](docs/reports/oom.md), 교착 재현·회피 비교와 [Deadlock 보고서](docs/reports/deadlock.md)를 사용자 실행·리뷰로 확인했습니다. 과거 TASK-002 비교 도구의 실패 경로 실행 검증은 사용자 선택으로 생략했습니다(정적 확인만). [CPU 보고서 초안](docs/reports/cpu.md)은 관측값과 한계를 기록했으며 OS CPU 급상승·보호 종료의 필수 증거가 부족합니다. [미션 원문](docs/harness/MISSION.md), [요구사항](docs/harness/REQUIREMENTS.md), [진행 상태](docs/harness/STATUS.md)를 기준으로 진행합니다.

## 프로젝트 구조

- [agent-app-leak/](agent-app-leak/): 제공된 x86·arm64 바이너리.
- [prepare-env.sh](prepare-env.sh): Linux 실행 조건 확인, 기본 환경 설정, 앱 시작과 실행별 로그 분리.
- [monitor.sh](monitor.sh): 설정값으로 앱 실행·공통 관측·안전 정리를 수행하며, 기존 PID/CSV 단독 관제도 지원.
- [kill-agent-leak.sh](kill-agent-leak.sh): 이번 실행 PID를 자동 정리하거나 같은 계정의 정확한 저장소 바이너리를 수동으로 확인 후 정리.
- [docs/harness/](docs/harness/): 미션 원문, 요구사항, 작업 및 진행 기록.
- `runs/` (실행 시 생성): 실행별 원본 로그와 관제 기록. Git에서는 제외.

## 실행 환경 및 방법

실행은 Linux 머신 내부의 일반 사용자 계정에서 진행하며 Docker는 사용하지 않습니다. 초기 기록에는 macOS 호스트의 OrbStack Linux가 있으나, 2026-10-26 사용자 출력에서 확인한 현재 환경은 x86_64 Linux·논리 CPU 6개·KVM입니다. 이 출력만으로 호스트나 OrbStack 구성을 단정하지 않습니다.

아래 절차의 앱 실행·CSV 관제·column 조회를 Ubuntu Linux 머신에서 사용자 실행으로 확인했습니다. 실행마다 부트 성공과 실제 로그를 확인하세요.

메모리 설정 전후 비교는 아래 [공통 관측](#설정값만으로-공통-관측)을 설정만 바꿔 두 번 실행합니다.

### 1. 환경 준비와 앱 시작

```bash
source ./prepare-env.sh
```

설정을 지정할 때는 위 명령 대신 세 값을 순서대로 전달합니다.

```bash
source ./prepare-env.sh 512 40 false
```

스크립트가 Linux·일반 사용자·필수 명령·포트 상태를 확인하고, 머신 아키텍처에 맞는 바이너리를 선택합니다. `AGENT_HOME`이 비어 있으면 `$HOME/agent-leak-lab`을 사용하며, 필수 디렉터리와 미션의 **공개 시험용** `secret.key`를 준비합니다. 기존 키는 덮어쓰지 않고 내용만 비교하며 실제 credential은 사용하지 않습니다. macOS 호스트에서 실행하거나 호스트 아키텍처로 바이너리를 고르지 마세요.

`source`는 환경변수·`run_dir`·PID를 **현재 셸**에 남기기 위해 필요합니다. `bash ./prepare-env.sh`처럼 직접 실행하면 스크립트가 사용법을 출력하고 종료합니다. 인자 방식은 `메모리 MB CPU % 멀티스레드` 순서로 정확히 세 값을 받으며, 이전 실행의 환경변수보다 이 값들이 우선합니다. 메모리는 50~512, CPU는 10~100이고 멀티스레드는 `true/false`, `1/0`, `yes/no`를 받습니다. 무인자이면 기존 환경변수 또는 `MEMORY_LIMIT=256` MB, `CPU_MAX_OCCUPY=80`%, `MULTI_THREAD_ENABLE=false` 기본값을 사용합니다. 기본값에서는 메모리 증가와 MemoryGuard 종료를 확인했으며 CPU·Deadlock 재현 설정으로 검증한 것은 아닙니다. 위치 인자가 있는 함수·스크립트에서 무인자로 `source`하면 그 인자가 전달될 수 있으므로 세 값을 명시하세요. `AGENT_PORT=15034`는 고정입니다.

메모리 `128 80 false` → `256 80 false`, CPU `512 80 false` → `512 40 false`, 멀티스레드 `512 80 false` → `512 80 true`는 한 값씩 바꾸는 **입력 예시**입니다. 각 장애의 재현 조건이나 성공 결과로 검증된 값은 아닙니다. 개별 실험에서는 `source` 전에 환경변수를 설정할 수도 있으며, 공통 관측에서는 `monitor.sh`의 설정 인자를 바꿉니다. 전역 셸 설정 파일은 수정하지 않습니다.

준비가 성공하면 스크립트가 저장소의 `runs/` 아래에 `YYMMDD-HHMMSS_메모리_CPU_멀티스레드-XXXXXX` 형식의 새 `run_dir`을 만들고 바이너리를 시작합니다. 예: `runs/261027-183000_128_40_false-Ab12Cd`. 이름순으로 실행 시각을 볼 수 있고 끝의 6자리는 같은 초·설정의 실행도 구분합니다. 시각은 초 단위이므로 같은 초에 시작한 실행끼리는 이름순이 정확한 시작 순서를 보장하지 않습니다. 폴더 이름에서는 `050`을 `50`, `1`·`yes`를 `true`, `0`·`no`를 `false`로 정규화하지만 앱에는 입력한 원래 설정을 전달합니다. `AGENT_HOME`의 키·업로드 경로는 그대로 두고, 실행별 `AGENT_LOG_DIR`만 새 디렉터리로 지정합니다. 기존 로컬 실행 증거 7개도 이 형식으로 이름만 변경했으며 원본 로그 내용과 홈 디렉터리 로그는 수정하지 않았습니다. 로그에 인쇄된 옛 절대 경로는 실행 당시 기록입니다. `runs/`는 Git에서 제외되므로 저장소를 복제할 때 이 원본 증거는 함께 전달되지 않습니다.

이 바이너리는 별도의 작업 자식 프로세스를 띄웁니다. `launcher_pid`는 부모, `app_pid`는 **관제할 자식 PID**입니다. 스크립트는 자식을 잠시 기다려 하나로 확인한 뒤 두 PID를 출력합니다. 자식을 확인하지 못하면 부모를 관제 대상으로 넘기지 않고 오류를 알립니다. 같은 셸에서 다시 실행했을 때 이전 PID가 살아 있거나 포트가 사용 중이면 중복 실행을 거부합니다. `app.log`에는 Linux 현지 시작 시각·표준 출력·표준 오류가 원문 그대로 저장되고, 앱 자체의 로그도 실행별 디렉터리에 모입니다. 준비·로그 생성에 실패하면 앱은 시작되지 않습니다. 출력의 `Started (boot unverified)`는 **부트 성공 판정이 아닙니다**.

`source ./prepare-env.sh`가 실패하면 다음 부트·관제·조회 단계로 진행하지 마세요. 같은 셸의 `app_pid`·`launcher_pid`·`run_dir`은 이전 실행 값일 수 있으며, 실패가 앱 시작 후 발생했다면 해당 시도의 프로세스가 남아 있을 수도 있습니다. 출력된 오류와 실제 프로세스·포트 상태, 해당 시도의 로그를 먼저 확인한 뒤 다시 준비하세요. 남아 있는 변수만으로 새 실행의 성공 여부를 판단하지 마세요.

### 2. 부트와 포트 확인

```bash
ss -ltnp '( sport = :15034 )'
tail -n 50 "$run_dir/app.log" | sed -E 's/^([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}),[0-9]{3}/\1/'
```

`0.0.0.0:15034`의 LISTEN 여부, `app_pid`와 실행 로그를 확인합니다. 실패했다면 실제 오류와 미충족 조건을 기록하고 성공으로 표시하지 마세요. 초기 설정에서는 앱이 빠르게 종료될 수 있으므로 관제 명령을 이어서 실행하세요.

## 관제 및 증거 수집

### 설정값만으로 공통 관측

저장소 루트의 일반 사용자 계정에서 `bash ./monitor.sh 메모리MB CPU% 멀티스레드 [관측초]`를 실행합니다. 관측 시간은 기본 60초, 지정할 때는 15~300초 정수입니다. 장애 종류는 입력하지 않습니다. 아래 값은 **입력 예시**입니다. 사용자는 새 공통 명령의 메모리 종료, CPU 임계치 기록 뒤 종료, 60초 생존 뒤 정리, 교착 대기 뒤 정리 경로를 실행해 확인했습니다. 이는 모든 설정·실패 경로의 검증이나 CPU 과점유 입증을 뜻하지 않습니다.

```bash
bash ./monitor.sh 128 40 false 60
bash ./monitor.sh 256 40 false 60
bash ./monitor.sh 512 40 true 60
```

새 실행의 고유 `run_dir`에는 원본 `app.log`, 앱이 생성했다면 `agent_app.log`, 약 1초 간격의 RSS·수명 평균 CPU·상태를 담는 `monitor.csv`, 대상 PID의 `top` **두 번째 프레임** 구간 CPU만 담는 `cpu-samples.csv`, 약 15초 간격의 앱 PID `ps -L` 표본인 `thread-observation.txt`, 간결한 `observation.txt`가 남습니다. CPU 파일은 전체 시스템 행을 저장하지 않습니다. CPU CSV의 `ppid_at_launch`는 앱 시작 때 확인한 부모 관계이고, `identity_status=unconfirmed_after_exit` 행은 `top` 직후 PID가 사라져 동일성을 재확인하지 못한 표본이므로 단독 앱 CPU 증거로 단정하지 않습니다. 요약에는 설정·PID 시작 식별값, 정리 전 앱 상태·수집 상태, MemoryGuard 임계치·자체 종료, CpuWorker 임계치, Watchdog 언급, 스레드 WAITING/BLOCKED를 **서로 다른 앱 로그 신호**로 표시하고 도구 정리·포트 결과를 남깁니다. 반복 CSV·CPU·스레드 행은 각 원본 파일에서 확인합니다. 앱 로그 읽기 실패와 부분 증거도 구분합니다. `CpuWorker`의 내부 `Current Load`·임계치 로그는 OS `%CPU` 급상승이나 Watchdog 종료의 증명이 아닙니다. MemoryGuard/Watchdog 종료는 앱 로그와 OS 표본을 함께 확인하고, 교착상태는 PID 생존·CPU/RSS 및 스레드·로그 정체를 여러 시각에서 비교해야 합니다. 시간이 끝나도 살아 있었다면 그 시점까지의 생존 하한만 확인됩니다.

관측 뒤 이번 실행에서 확인한 PID만 TERM, 필요 시 KILL하며 포트 15034 해제를 확인합니다. 준비 중 PID 식별값을 잡지 못했거나 수집·정리에 실패하면 종료값이 0이 아니고 부분 증거가 남을 수 있습니다. 다른 포트 점유자는 종료하지 않습니다. 다음 실행 전에는 `observation.txt`의 정리 결과와 포트 상태를 확인하세요. `kill-agent-leak.sh`를 인자 없이 수동 호출하면 현재 UID·이 저장소 실행 파일 경로가 정확히 일치하는 후보만 보여주고 확인을 받은 뒤 정리합니다. **같은 바이너리의 다른 실행도 후보가 될 수 있으므로 목록을 확인하세요.** 비대화형 무인자 호출은 정리하지 않습니다.

세 장애 모두 `monitor.sh` 설정값 호출로 관측합니다. 과거 mode별 명령은 제거했으며 과거 `runs/` 증거는 변경하지 않았습니다.

`column`은 CSV를 화면에서 열 맞춰 볼 때만 사용합니다. Linux 머신에서 설치 여부와 배포판을 먼저 확인하세요.

```bash
command -v column
cat /etc/os-release
```

`command -v column`이 경로를 출력하지 않고 `/etc/os-release`의 `ID`가 `ubuntu` 또는 `debian`이면, 필요한 경우 아래 명령으로 `bsdextrautils`를 직접 설치할 수 있습니다([Ubuntu 패키지](https://packages.ubuntu.com/jammy/amd64/bsdextrautils/filelist), [Debian 패키지](https://packages.debian.org/bookworm/amd64/bsdextrautils/filelist)). 이미 설치되어 있으면 건너뛰세요. 관제 스크립트는 `column` 없이도 CSV를 기록합니다.

```bash
sudo apt update
sudo apt install bsdextrautils
```

새 실행에서 관제까지 한 번에 시작하려면 **같은 Bash 셸**에서 아래 명령을 실행합니다. 초기 설정처럼 약 30초 안에 종료되는 경우에도 `source`가 자식 PID를 확인한 직후 관제를 시작할 수 있습니다.

```bash
source ./prepare-env.sh && bash ./monitor.sh "$app_pid" "$run_dir/monitor.csv"
```

세 값을 지정할 때는 같은 명령에서 `source ./prepare-env.sh 512 40 false`로 바꾸면 됩니다. 관제 명령과 자식 PID 사용법은 동일합니다.

위 명령이 성공했을 때만 같은 셸에서 이번 실행의 기록을 조회합니다.

```bash
column -s, -t "$run_dir/monitor.csv"
tail -n 50 "$run_dir/app.log" | sed -E 's/^([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}),[0-9]{3}/\1/'
```

이미 1단계에서 `source ./prepare-env.sh`를 마쳤다면 다시 `source`하지 말고 `bash ./monitor.sh "$app_pid" "$run_dir/monitor.csv"`만 실행하세요. `column -s, -t "$run_dir/monitor.csv"`는 저장된 CSV를 읽기 쉬운 표로 화면에 표시할 뿐 원본을 바꾸지 않습니다. `column`이 없으면 `cat "$run_dir/monitor.csv"`로 확인할 수 있습니다. `app.log`의 `launch_local`과 `monitor.csv`의 현지 시각을 대조합니다. 앱 로그 조회 명령은 밀리초만 화면에서 숨기며 **원본 `app.log`는 변경하지 않습니다**. 두 기록의 날짜·시간은 `년-월-일 시:분:초` 형식으로 읽으면 됩니다. 기존 CSV·LOG와 홈 디렉터리 로그는 그대로 보존하며, 과거 UTC 로그와 비교할 때는 시간대 차이를 고려하세요. 포트의 LISTEN 상태는 앱이 살아 있을 때 확인해야 합니다.

CSV의 `date_local`과 `time_local`은 Linux 머신의 현지 관측 날짜·시각입니다. `rss_kib`는 프로세스의 물리 메모리 점유량(KiB), `mem_percent_system`은 시스템 전체 메모리 대비 비율(%)입니다. 이를 `MEMORY_LIMIT` 소진율로 해석하지 않습니다. `cpu_percent_lifetime`은 `ps`가 보여 주는 **프로세스 시작 이후의 평균 CPU 사용률**(%)이므로 순간 급상승을 놓칠 수 있습니다. 새 설정값 호출은 `cpu-samples.csv`와 `thread-observation.txt`도 저장합니다. 기존 2인자 PID/CSV 호출에서는 이 추가 파일을 만들지 않습니다.

스크립트는 1초마다 기록하고, 대상이 종료되면 `EXITED` 행을 남깁니다. 시작 전에 PID가 없거나 로그를 새로 만들 수 없으면 오류로 끝납니다. 관제만 중단하려면 `Ctrl+C`를 누르세요. 앱은 관제 중단으로 종료되지 않으며, 계속 실행 중인지 `ps -p "$app_pid"`로 확인할 수 있습니다. PID가 나중에 재사용될 수 있으므로 각 실행의 PID와 로그 디렉터리를 함께 기록하고, 오래된 PID로 관제를 다시 시작하지 마세요. 관제 파일은 기존 경로를 덮어쓰지 않습니다. 쓰기 오류가 나면 수집 실패를 알리며 일부 행만 남을 수 있습니다.

## 장애 보고서 및 비교 결과

### CPU 관측과 비교

CPU 설정만 바꾼 두 번의 [공통 관측](#설정값만으로-공통-관측)을 수행합니다. `cpu-samples.csv`는 이번 실행 launcher·앱 PID의 `top` 첫 프레임을 버리고 두 번째 프레임의 `%CPU`·누적 CPU 시간을 기록합니다. `observation.txt`의 PID·부모 관계·시작 식별값과 대조하세요. 사용자 `top` 구성에 따라 필수 열을 읽지 못하면 수집 실패로 반환할 수 있습니다. 앱의 내부 `Current Load`와 OS `%CPU`는 같은 값이 아닙니다. 과거 [CPU 보고서 초안](docs/reports/cpu.md)의 부족한 급상승·Watchdog 근거는 새 실행이 실제로 확보되기 전까지 미완료입니다.

### 교착상태 관측 및 비교

Linux 머신의 저장소 루트에서 일반 사용자로 실행합니다. 메모리 512MB, CPU 40%를 유지한 60초 비교에서 `true`는 두 스레드의 A/B 락 순환 대기와 로그 정체, `false`는 다른 앱 경로에서 작업·로그 진행을 확인했습니다. 실제 증거와 해석 한계는 [Deadlock 보고서](docs/reports/deadlock.md)에 정리했습니다. 이 결과가 모든 실행의 재현이나 영구 회피를 보장하지는 않습니다.

```bash
bash ./monitor.sh 512 40 true 60
```

[공통 관측](#설정값만으로-공통-관측)의 첫 실행 결과와 정리 상태를 확인한 뒤 `bash ./monitor.sh 512 40 false 60`을 실행하면 멀티스레드 설정만 바꾼 비교가 됩니다. 기존 앱이나 15034 포트가 사용 중이면 상태를 확인한 뒤 다음 실행을 시작하세요.

`thread-observation.txt`에는 약 15초 간격으로 이번 실행 앱 PID의 `ps -L` 스레드 표본만 저장합니다. `wchan`은 커널 대기 위치의 참고값이며 락 소유자나 순환 대기를 직접 증명하지 않습니다. PID 생존, CPU·RSS와 로그 정체, 스레드별 대기 관계를 함께 판단하며 낮은 CPU만으로 교착상태를 확정하지 마세요.

현재 `monitor.sh`는 관측 종료 당시 상태를 요약에 남긴 후 이번 실행 앱을 자동 정리합니다. 과거 true/false 두 사용자 실행은 **변경 전 스크립트**의 검증 기록입니다. 새 공통 명령의 true 교착 대기·60초 생존 후 정리 경로는 사용자 실행으로 확인했으며, false와 설정을 한 가지만 달리한 비교 근거는 기존 [교착 보고서](docs/reports/deadlock.md)를 따릅니다. 실패나 중단 시 부분 파일과 최종 PID·포트 상태를 확인하세요.

### 메모리 설정 전후 비교

**Linux 머신의 저장소 루트**에서 일반 사용자로, 메모리 값만 바꿔 [공통 관측](#설정값만으로-공통-관측)을 두 번 실행합니다. 각 실행은 최대 지정 시간 동안 관측하고 앱이 남아 있으면 정리합니다. 첫 실행의 `observation.txt`에서 정리 결과와 포트 해제를 확인한 뒤 두 번째를 시작하세요.

```bash
bash ./monitor.sh 128 40 false 60
bash ./monitor.sh 300 40 false 60
```

위 값은 설정 예시입니다. [OOM 보고서](docs/reports/oom.md)의 128MB·300MB 결과는 별도로 사용자가 실행한 공통 관측 두 건을 비교한 것입니다. 당시 128MB는 30초, 300MB는 60초 한도로 관측했고 300MB 앱은 관측 끝에도 살아 있었습니다. 보고서 확인을 위한 재실행은 필요하지 않습니다.

각 실행의 `app.log`에서 `All Boot Checks Passed!`와 `Agent READY`를 확인하고, `monitor.csv`의 RSS 변화·`EXITED` 여부와 앱 로그의 MemoryGuard 신호를 대조하세요. 수집 또는 정리가 실패하면 부분 증거와 PID·포트 상태를 먼저 확인합니다. 완료 출력만으로 종료 원인을 확정하지 않습니다. 첫 RUNNING과 EXITED 표본의 시각 차이는 실제 시작·종료 시간과 다르고 최고 표본 RSS도 실제 최고 메모리가 아닐 수 있습니다. 앱 로그의 Heap(MB), CSV의 RSS(KiB), 시스템 대비 `%MEM`은 서로 다른 값입니다. MemoryGuard 종료와 OS OOM Killer를 실제 로그로 구분합니다. 두 실행의 원본을 보존하고, Git에서 제외되는 `runs/`의 핵심 근거 행은 보고서에 별도로 옮깁니다.

| 분석 대상 | 비교할 설정 | 상태 |
| --- | --- | --- |
| 메모리 증가 및 MemoryGuard 종료 | MEMORY_LIMIT | [128/300MB·CPU 40% 비교](docs/reports/oom.md): 128MB는 17초 뒤 종료, 300MB는 60초 관측 끝에도 생존 |
| CPU 과점유 및 Watchdog 종료 | CPU_MAX_OCCUPY | [관측 초안](docs/reports/cpu.md): OS 과점유·보호 종료 증거 부족 |
| 교착상태 재현 및 회피 | MULTI_THREAD_ENABLE | [true/false 비교](docs/reports/deadlock.md) 완료: 순환 대기·정체 → 작업 진행 |

128MB 실행은 `MemoryGuard` 자체 종료, 300MB 실행은 `MemoryWorker` 정리·회복 뒤 60초 관측 끝까지 생존했습니다. 두 실행의 앱 작업 경로와 관측 상한이 달라 한도 변경만의 효과로 단정하지 않습니다. [OOM 보고서](docs/reports/oom.md)에 핵심 원문과 측정 기준을 기록했습니다. Deadlock 비교·보고서는 완료했으며 CPU 보고서는 필수 증거 보완이 남아 있습니다.

## 확인된 동작

사용자 실행에서 CSV 수집·종료 감지, column 조회, 기존 CSV 덮어쓰기 방지(전후 해시 동일), 잘못된 저장 경로의 실패 반환, 준비 실패 안내를 확인했습니다. 관제를 Ctrl+C로 중단한 직후 앱 프로세스가 살아 있는 것도 확인했습니다. 상세 근거는 [WORKLOG](docs/harness/WORKLOG.md)에 기록합니다. 모든 환경·오류 경로를 검증했다는 의미는 아닙니다.

## 학습 자료

[학습 노트](docs/study-note.md)에서 TASK-001 실행 준비·CSV 관제 → TASK-002 메모리 비교·증거 해석 → [TASK-004 교착상태·단일 관측 도구](docs/study-note.md#task-004-교착상태-관측과-멀티스레드-설정-비교) 순서로 읽을 수 있습니다. TASK-003 CPU의 최종 학습 정리는 미완료입니다.
