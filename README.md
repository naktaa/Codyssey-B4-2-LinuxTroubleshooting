# Linux Troubleshooting

제공된 `agent-leak-app`을 Linux에서 실행하고 메모리 누수, CPU 과점유, 교착상태를 관측하여 증거 기반 장애 보고서 3건을 작성하는 교육 미션입니다.

실행·관제 도구의 기본 동작과 OOM 메모리 설정 비교를 사용자 실행으로 확인하고 [OOM 보고서](docs/reports/oom.md)를 작성했습니다. TASK-002 리뷰 지적을 처리 중이며 CPU·Deadlock 비교와 보고서는 대기 중입니다. [미션 원문](docs/harness/MISSION.md), [요구사항](docs/harness/REQUIREMENTS.md), [진행 상태](docs/harness/STATUS.md)를 기준으로 진행합니다.

## 프로젝트 구조

- [agent-app-leak/](agent-app-leak/): 제공된 x86·arm64 바이너리.
- [prepare-env.sh](prepare-env.sh): Linux 실행 조건 확인, 기본 환경 설정, 앱 시작과 실행별 로그 분리.
- [monitor.sh](monitor.sh): 대상 PID의 CPU·메모리 지표를 1초마다 CSV로 기록.
- [docs/harness/](docs/harness/): 미션 원문, 요구사항, 작업 및 진행 기록.
- `runs/` (실행 시 생성): 실행별 원본 로그와 관제 기록. Git에서는 제외.

## 실행 환경 및 방법

macOS 호스트의 OrbStack Linux 머신을 사용합니다. 실행은 Linux 머신 내부의 일반 사용자 계정에서 진행하며 Docker는 사용하지 않습니다.

아래 절차의 앱 실행·CSV 관제·column 조회를 Ubuntu Linux 머신에서 사용자 실행으로 확인했습니다. 실행마다 부트 성공과 실제 로그를 확인하세요.

TASK-002 메모리 비교는 아래 [한 명령 실행 절](#메모리-설정-전후-비교--한-명령으로-실행)을 사용합니다. 비교 스크립트가 이 절의 준비·관제 도구를 순서대로 호출합니다.

### 1. 환경 준비와 앱 시작

```bash
source ./prepare-env.sh
```

스크립트가 Linux·일반 사용자·필수 명령·포트 상태를 확인하고, 머신 아키텍처에 맞는 바이너리를 선택합니다. `AGENT_HOME`이 비어 있으면 `$HOME/agent-leak-lab`을 사용하며, 필수 디렉터리와 미션의 **공개 시험용** `secret.key`를 준비합니다. 기존 키는 덮어쓰지 않고 내용만 비교하며 실제 credential은 사용하지 않습니다. macOS 호스트에서 실행하거나 호스트 아키텍처로 바이너리를 고르지 마세요.

`source`는 환경변수·`run_dir`·PID를 **현재 셸**에 남기기 위해 필요합니다. `bash ./prepare-env.sh`처럼 직접 실행하면 스크립트가 사용법을 출력하고 종료합니다. 스크립트는 `AGENT_PORT=15034`, `MEMORY_LIMIT=256` MB, `CPU_MAX_OCCUPY=80`%, `MULTI_THREAD_ENABLE=false`를 기본값으로 사용합니다. 후자의 세 값은 **관측 시작값**입니다. 이 설정으로 메모리 증가와 MemoryGuard 종료를 확인했으며 CPU·Deadlock 재현 설정으로 검증한 것은 아닙니다. 개별 실험에서는 `source` 전에 환경변수를 설정할 수 있고, 아래 메모리 비교에서는 [비교 스크립트](run-memory-comparison.sh) 상단의 값만 수정합니다. 전역 셸 설정 파일은 수정하지 않습니다.

준비가 성공하면 스크립트가 저장소의 `runs/` 아래에 `run-년-월-일_시-분-초-XXXXXX` 형식의 새 `run_dir`을 만들고 바이너리를 시작합니다. 끝의 6자리는 실행 구분용 임의 문자입니다. `AGENT_HOME`의 키·업로드 경로는 그대로 두고, 실행별 `AGENT_LOG_DIR`만 새 디렉터리로 지정합니다. 기존 홈 디렉터리 로그는 이동하거나 삭제하지 않습니다. `runs/`는 Git에서 제외되므로 저장소를 복제할 때 이 원본 증거는 함께 전달되지 않습니다.

이 바이너리는 별도의 작업 자식 프로세스를 띄웁니다. `launcher_pid`는 부모, `app_pid`는 **관제할 자식 PID**입니다. 스크립트는 자식을 잠시 기다려 하나로 확인한 뒤 두 PID를 출력합니다. 자식을 확인하지 못하면 부모를 관제 대상으로 넘기지 않고 오류를 알립니다. 같은 셸에서 다시 실행했을 때 이전 PID가 살아 있거나 포트가 사용 중이면 중복 실행을 거부합니다. `app.log`에는 Linux 현지 시작 시각·표준 출력·표준 오류가 원문 그대로 저장되고, 앱 자체의 로그도 실행별 디렉터리에 모입니다. 준비·로그 생성에 실패하면 앱은 시작되지 않습니다. 출력의 `Started (boot unverified)`는 **부트 성공 판정이 아닙니다**.

`source ./prepare-env.sh`가 실패하면 다음 부트·관제·조회 단계로 진행하지 마세요. 같은 셸의 `app_pid`·`launcher_pid`·`run_dir`은 이전 실행 값일 수 있으며, 실패가 앱 시작 후 발생했다면 해당 시도의 프로세스가 남아 있을 수도 있습니다. 출력된 오류와 실제 프로세스·포트 상태, 해당 시도의 로그를 먼저 확인한 뒤 다시 준비하세요. 남아 있는 변수만으로 새 실행의 성공 여부를 판단하지 마세요.

### 2. 부트와 포트 확인

```bash
ss -ltnp '( sport = :15034 )'
tail -n 50 "$run_dir/app.log" | sed -E 's/^([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}),[0-9]{3}/\1/'
```

`0.0.0.0:15034`의 LISTEN 여부, `app_pid`와 실행 로그를 확인합니다. 실패했다면 실제 오류와 미충족 조건을 기록하고 성공으로 표시하지 마세요. 초기 설정에서는 앱이 빠르게 종료될 수 있으므로 관제 명령을 이어서 실행하세요.

## 관제 및 증거 수집

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

위 명령이 성공했을 때만 같은 셸에서 이번 실행의 기록을 조회합니다.

```bash
column -s, -t "$run_dir/monitor.csv"
tail -n 50 "$run_dir/app.log" | sed -E 's/^([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}),[0-9]{3}/\1/'
```

이미 1단계에서 `source ./prepare-env.sh`를 마쳤다면 다시 `source`하지 말고 `bash ./monitor.sh "$app_pid" "$run_dir/monitor.csv"`만 실행하세요. `column -s, -t "$run_dir/monitor.csv"`는 저장된 CSV를 읽기 쉬운 표로 화면에 표시할 뿐 원본을 바꾸지 않습니다. `column`이 없으면 `cat "$run_dir/monitor.csv"`로 확인할 수 있습니다. `app.log`의 `launch_local`과 `monitor.csv`의 현지 시각을 대조합니다. 앱 로그 조회 명령은 밀리초만 화면에서 숨기며 **원본 `app.log`는 변경하지 않습니다**. 두 기록의 날짜·시간은 `년-월-일 시:분:초` 형식으로 읽으면 됩니다. 기존 CSV·LOG와 홈 디렉터리 로그는 그대로 보존하며, 과거 UTC 로그와 비교할 때는 시간대 차이를 고려하세요. 포트의 LISTEN 상태는 앱이 살아 있을 때 확인해야 합니다.

CSV의 `date_local`과 `time_local`은 Linux 머신의 현지 관측 날짜·시각입니다. `rss_kib`는 프로세스의 물리 메모리 점유량(KiB), `mem_percent_system`은 시스템 전체 메모리 대비 비율(%)입니다. 이를 `MEMORY_LIMIT` 소진율로 해석하지 않습니다. `cpu_percent_lifetime`은 `ps`가 보여 주는 **프로세스 시작 이후의 평균 CPU 사용률**(%)이므로 순간 급상승을 놓칠 수 있습니다. CPU 피크는 별도의 `top -p "$app_pid"` 출력도 확보하세요. 교착상태 조사 시에는 `ps -L -p "$app_pid" -o pid,tid,stat,%cpu,rss,comm`으로 스레드 상태를 추가 확인할 수 있습니다.

스크립트는 1초마다 기록하고, 대상이 종료되면 `EXITED` 행을 남깁니다. 시작 전에 PID가 없거나 로그를 새로 만들 수 없으면 오류로 끝납니다. 관제만 중단하려면 `Ctrl+C`를 누르세요. 앱은 관제 중단으로 종료되지 않으며, 계속 실행 중인지 `ps -p "$app_pid"`로 확인할 수 있습니다. PID가 나중에 재사용될 수 있으므로 각 실행의 PID와 로그 디렉터리를 함께 기록하고, 오래된 PID로 관제를 다시 시작하지 마세요. 관제 파일은 기존 경로를 덮어쓰지 않습니다. 쓰기 오류가 나면 수집 실패를 알리며 일부 행만 남을 수 있습니다.

## 장애 보고서 및 비교 결과

### 메모리 설정 전후 비교 — 한 명령으로 실행

OrbStack **Linux 머신의 저장소 루트**에서 일반 사용자로 실행합니다. 설정을 바꾸려면 [run-memory-comparison.sh](run-memory-comparison.sh) 상단의 `BEFORE_MEMORY_LIMIT`, `AFTER_MEMORY_LIMIT`, `CPU_LIMIT`, `MULTI_THREAD`, `AGENT_HOME_DIR`만 편집합니다. 현재 기본값은 **128MB → 256MB**, CPU 80%, 멀티스레드 비활성입니다. 첫 256MB → 512MB 실행에서 512MB가 다른 작업으로 전환되어 메모리 생존 시간 비교가 성립하지 않아 기본값을 바꿨습니다. 두 메모리 한계는 50~512MB 범위의 서로 다른 정수여야 합니다. 실제 계정의 비밀값을 이 파일에 적지 마세요.

```bash
./run-memory-comparison.sh
```

스크립트는 먼저 고유한 `runs/comparison-.../output.log`를 만들고, 화면의 표준 출력·오류를 이 파일에도 저장합니다. 각 설정에서 기존 준비 도구로 앱을 시작하고, 별도의 `runs/run-...` 디렉터리에 `app.log`와 `monitor.csv`를 남긴 뒤 관제가 끝날 때까지 기다립니다. 비교 출력 로그에는 설정, 두 실행의 원본 경로·부모/자식 PID, 첫 `RUNNING`~`EXITED` 관측 시간, 최고 **표본** RSS, CSV 일부 행, 앱 로그의 시작·마지막 부분과 `experiment_exit_code`·`log_exit_code`·`final_exit_code`가 남습니다. 마지막에 표시되는 `comparison_log` 경로만 알려주시면 같은 저장소의 원본 CSV·앱 로그와 대조할 수 있습니다. 터미널 전체를 복사할 필요는 없습니다.

첫 실행의 준비·관제·측정·부트 성공 확인 또는 비교 출력 저장이 실패하거나 앱 프로세스·15034 포트가 아직 사용 중이면 다음 실행을 시작하지 않습니다. 부트 성공은 각 `app.log`의 `All Boot Checks Passed!`와 `Agent READY`로 확인합니다. 로그 저장 또는 실험이 실패하면 최종 종료 코드를 0으로 표시하지 않습니다. 남은 프로세스를 자동으로 종료하거나 기존 증거를 지우지 않으므로, 실패 메시지의 PID·경로와 실제 상태를 먼저 확인하세요. 완료 출력만으로 종료 원인을 확정하지 않고 두 `app.log`를 확인합니다.

관측 시간은 프로세스의 실제 시작·종료 시간이 아니라 **첫 RUNNING 표본과 EXITED 관측 시각의 차이**입니다. 약 1초 간격 수집과 명령 수행 시간 때문에 오차가 있고, 최고 표본 RSS도 실제 최고 메모리는 아닐 수 있습니다. 앱 로그의 Heap(MB), CSV의 RSS(KiB), 시스템 대비 `%MEM`은 서로 다른 값입니다. MemoryGuard 종료와 OS OOM Killer를 혼동하지 않고 실제 로그로 구분합니다. 비교 출력 로그와 두 실행의 원본 CSV·앱 로그를 보존해 주세요. `runs/`는 Git에서 제외되므로 보고서에는 근거 행을 별도로 옮깁니다.

| 분석 대상 | 비교할 설정 | 상태 |
| --- | --- | --- |
| 메모리 증가 및 MemoryGuard 종료 | MEMORY_LIMIT | [128/256MB 비교](docs/reports/oom.md) 확인: 관측 생존 시간 17초 → 33초 |
| CPU 과점유 및 Watchdog 종료 | CPU_MAX_OCCUPY | 실험 전 |
| 교착상태 재현 및 회피 | MULTI_THREAD_ENABLE | 실험 전 |

128/256MB 사용자 실행에서는 두 설정 모두 `MemoryWorker`의 메모리 증가와 MemoryGuard 자체 종료가 기록됐습니다. 관측 시간은 17초와 33초로 16초 늘었지만, 두 실행 모두 결국 종료됐습니다. [OOM 보고서](docs/reports/oom.md)에 원본 발췌, 측정 기준과 첫 256/512MB 비교의 한계를 기록했습니다. CPU·Deadlock 본 보고서는 해당 TASK에서 작성합니다.

## 확인된 동작

사용자 실행에서 CSV 수집·종료 감지, column 조회, 기존 CSV 덮어쓰기 방지(전후 해시 동일), 잘못된 저장 경로의 실패 반환, 준비 실패 안내를 확인했습니다. 관제를 Ctrl+C로 중단한 직후 앱 프로세스가 살아 있는 것도 확인했습니다. 상세 근거는 [WORKLOG](docs/harness/WORKLOG.md)에 기록합니다. 모든 환경·오류 경로를 검증했다는 의미는 아닙니다.

## 학습 자료

[학습 노트](docs/study-note.md)에서 TASK-001의 실행 준비 → 부모/자식 PID → CSV 수집 → 파일 보호·실패 처리와 TASK-002의 메모리 비교·증거 해석 순서로 읽을 수 있습니다. 이후 TASK의 학습 내용도 같은 파일에 이어서 작성합니다.
