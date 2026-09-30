# [Bug] OOM Crash - MemoryGuard 종료와 메모리 한도 비교

> 상태: 2026-09-30 사용자 실행 결과 확인. 128MB→256MB 비교에서 같은 메모리 증가 작업이 재현됐고 관측 생존 시간이 17초→33초로 늘었다. 제목의 OOM은 미션 분류이며 OS OOM Killer 작동을 뜻하지 않는다.

## 1. Description (현상 설명)

OrbStack Linux 머신의 일반 사용자로 [비교 스크립트](../../run-memory-comparison.sh)를 실행했다. `MEMORY_LIMIT`만 128MB에서 256MB로 바꿨고 `CPU_MAX_OCCUPY=80%`, `MULTI_THREAD_ENABLE=false`, `AGENT_HOME` 및 포트 15034는 유지했다. 두 실행 모두 부트 검사 6개를 통과하고 `Agent READY`를 출력했다. 두 실행의 `MemoryWorker`가 Heap을 25MB씩 늘렸으며, 각 한계를 넘은 뒤 `MemoryGuard`가 자체 종료를 기록했다.

## 2. Evidence & Logs (증거 자료)

사용자 실행의 [비교 출력](../../runs/comparison-8mGJ3y/output.log)을 원본 CSV·앱 로그와 대조했다. Before 원본: [monitor.csv](../../runs/run-2026-09-30_20-12-33-L66NZ7/monitor.csv), [app.log](../../runs/run-2026-09-30_20-12-33-L66NZ7/app.log). After 원본: [monitor.csv](../../runs/run-2026-09-30_20-12-51-NfJm4C/monitor.csv), [app.log](../../runs/run-2026-09-30_20-12-51-NfJm4C/app.log). `runs/`는 Git 제외 대상이므로 핵심 행을 아래에도 남긴다. 원본 링크는 해당 로컬 작업 공간에서만 열린다.

Before `app.log`의 부트 기록 발췌:

```text
   ... MEMORY_LIMIT=128MB, CPU_MAX_OCCUPY=80%, MULTI_THREAD_ENABLE=False
All Boot Checks Passed!
Agent READY
```

After `app.log`의 부트 기록 발췌:

```text
   ... MEMORY_LIMIT=256MB, CPU_MAX_OCCUPY=80%, MULTI_THREAD_ENABLE=False
All Boot Checks Passed!
Agent READY
```

비교 출력의 완료 코드:

```text
experiment_exit_code=0 log_exit_code=0 final_exit_code=0
```

| 항목 | Before | After |
| --- | --- | --- |
| MEMORY_LIMIT | 128MB | 256MB |
| CPU_MAX_OCCUPY / MULTI_THREAD_ENABLE | 80% / false | 80% / false |
| 실행 디렉터리 | `run-2026-09-30_20-12-33-L66NZ7` | `run-2026-09-30_20-12-51-NfJm4C` |
| launcher PID / 관제 자식 PID | 8656 / 8661 | 8785 / 8790 |
| 부트 | 6개 검사 통과, `Agent READY` | 6개 검사 통과, `Agent READY` |
| 첫 RUNNING → EXITED 관측 | 20:12:34 → 20:12:51 | 20:12:52 → 20:13:25 |
| 관측 생존 시간 | 17초 | 33초 (+16초) |
| RSS 시작 → 최고 표본 | 18,500 → 146,520 KiB | 18,588 → 274,628 KiB |
| 작업·종료 로그 | MemoryWorker, Heap 150MB에서 MemoryGuard 자체 종료 | MemoryWorker, Heap 275MB에서 MemoryGuard 자체 종료 |

Before `monitor.csv`의 PID 8661 행 발췌:

```csv
2026-09-30,20:12:34,8661,5.0,18500,0.1,RUNNING
2026-09-30,20:12:42,8661,1.3,95312,0.5,RUNNING
2026-09-30,20:12:48,8661,1.4,146520,0.8,RUNNING
2026-09-30,20:12:51,8661,,,,EXITED
```

Before `app.log`의 종료 직전 원문:

```text
2026-09-30 20:12:48,038 [INFO] [MemoryWorker] Current Heap: 125MB
2026-09-30 20:12:51,096 [INFO] [MemoryWorker] Current Heap: 150MB
2026-09-30 20:12:51,096 [CRITICAL] [MemoryGuard] Memory limit exceeded (150MB >= 128MB) / (Recommend Over 256MB)
2026-09-30 20:12:51,096 [CRITICAL] [MemoryGuard] Self-terminating process 8661 to prevent system instability.
```

After `monitor.csv`의 PID 8790 행 발췌:

```csv
2026-09-30,20:12:52,8790,4.0,18588,0.1,RUNNING
2026-09-30,20:13:00,8790,1.4,95400,0.5,RUNNING
2026-09-30,20:13:11,8790,0.9,172212,1.0,RUNNING
2026-09-30,20:13:21,8790,1.0,249024,1.5,RUNNING
2026-09-30,20:13:22,8790,1.1,274628,1.6,RUNNING
2026-09-30,20:13:25,8790,,,,EXITED
```

After `app.log`의 종료 직전 원문:

```text
2026-09-30 20:13:21,433 [INFO] [MemoryWorker] Current Heap: 250MB
2026-09-30 20:13:24,469 [INFO] [MemoryWorker] Current Heap: 275MB
2026-09-30 20:13:24,470 [CRITICAL] [MemoryGuard] Memory limit exceeded (275MB >= 256MB) / (Recommend Over 256MB)
2026-09-30 20:13:24,470 [CRITICAL] [MemoryGuard] Self-terminating process 8790 to prevent system instability.
```

비교 출력에는 `experiment_exit_code=0 log_exit_code=0 final_exit_code=0`이 기록됐다. 이는 두 실행의 수집과 비교 출력 저장이 정상 완료됐다는 뜻이며 앱이 종료되지 않았다는 뜻은 아니다. 출력의 launcher `Killed` 알림만으로 OS OOM Killer 작동을 판단하지 않는다.

## 3. Root Cause Analysis (원인 분석)

두 실행에서 RSS가 단계적으로 증가했고 앱 Heap 로그도 25MB 간격으로 상승했다. 128MB 설정에서는 Heap 150MB, 256MB 설정에서는 Heap 275MB에서 앱이 한계 초과와 자체 종료를 기록했다. 관제 PID와 종료 로그의 PID가 각각 일치한다. 이번 관측에서는 메모리 증가와 앱의 MemoryGuard 정책이 종료를 설명한다. 제공 바이너리 내부에서 어떤 객체가 해제되지 않았는지는 이 외부 증거만으로 확정하지 않는다.

RSS(KiB)는 물리 메모리 점유 표본이고 앱 Heap(MB)은 앱이 자체 기록한 값이다. CSV의 `%MEM`은 시스템 전체 메모리 대비 비율이다. 이 셋을 같은 수치나 MEMORY_LIMIT 소진율로 취급하지 않는다. OS OOM Killer 이벤트를 확인한 자료는 없으며, 앱의 자체 종료 로그와 구분한다.

## 4. Workaround & Verification (조치 및 검증)

임시 조치로 MEMORY_LIMIT을 128MB에서 256MB로 높이자, 같은 `MemoryWorker` 작업의 **관측 생존 시간이 17초에서 33초로 16초 늘었다**. 두 실행 모두 결국 MemoryGuard로 종료했으므로 한도 상향은 메모리 증가 문제를 해결하지 않는다. 한 번의 비교에서 관측한 결과이며 모든 실행에서 동일한 시간을 보장하지 않는다.

시간은 각 CSV의 **첫 RUNNING 표본부터 EXITED 관측까지**의 차이로 계산했다. 실제 프로세스 시작·종료 순간과 다르고, 약 1초 간격으로 수집한 최고 RSS 표본은 실제 최고 사용량보다 낮을 수 있다.

## 앞선 256MB→512MB 비교의 한계

아래는 보존한 첫 비교의 기록이다. 당시에는 두 실행의 작업·종료 경로가 달라 메모리 한도 상향 효과를 판단할 수 없었다. 이후 위 128MB→256MB 비교에서 같은 작업의 생존 시간 증가를 확인했다.

### 당시 현상

2026-09-30 OrbStack Linux 머신의 일반 사용자로 [비교 스크립트](../../run-memory-comparison.sh)를 한 번 실행했다. 당시 스크립트 기본값은 256MB→512MB였으며, 이 결과를 확인한 뒤 승인에 따라 현재 기본값을 128MB→256MB로 변경했다. 두 실행 모두 부트 6개 검사를 통과하고 `Agent READY`를 출력했다. `CPU_MAX_OCCUPY=80%`, `MULTI_THREAD_ENABLE=false`, `AGENT_HOME`과 포트 15034는 같았고 `MEMORY_LIMIT`만 256MB에서 512MB로 바꾸었다.

256MB에서는 자식 PID 6105의 RSS가 증가하다가 앱 로그의 MemoryGuard 임계치 초과·자체 종료 메시지 직후 관제에서 `EXITED`가 기록됐다. 512MB에서는 자식 PID 6311의 RSS가 거의 일정했고 `CpuWorker`의 임계치 위반 로그 뒤 `EXITED`가 기록됐다. 각 실행에서 실제로 수행한 작업이 달라, 512MB를 같은 메모리 증가 작업의 생존 시간 연장 사례로 볼 수 없다.

### 당시 증거

아래 수치는 사용자 터미널 출력과 해당 실행의 원본 CSV·앱 로그를 대조했다. 로컬 원본: Before [monitor.csv](../../runs/run-2026-09-30_19-36-55-YtfcD0/monitor.csv)·[app.log](../../runs/run-2026-09-30_19-36-55-YtfcD0/app.log), After [monitor.csv](../../runs/run-2026-09-30_19-37-28-bdNdQM/monitor.csv)·[app.log](../../runs/run-2026-09-30_19-37-28-bdNdQM/app.log). `runs/`는 Git 제외 대상이므로 주요 원문을 아래에도 남긴다. 링크는 원본이 있는 로컬 작업 공간에서만 열린다.

| 항목 | Before | After |
| --- | --- | --- |
| MEMORY_LIMIT | 256MB | 512MB |
| CPU_MAX_OCCUPY / MULTI_THREAD_ENABLE | 80% / false | 80% / false |
| 실행 디렉터리 | `run-2026-09-30_19-36-55-YtfcD0` | `run-2026-09-30_19-37-28-bdNdQM` |
| launcher PID / 관제 자식 PID | 6100 / 6105 | 6306 / 6311 |
| 부트 | 6개 검사 통과, `Agent READY` | 6개 검사 통과, `Agent READY` |
| 첫 RUNNING → EXITED 관측 | 19:36:56 → 19:37:28 | 19:37:29 → 19:37:59 |
| 관측 생존 시간 | 32초 | 30초 |
| RSS 시작 → 최고 표본 | 18,488 → 274,480 KiB | 18,464 → 18,528 KiB |
| 작업·마지막 원인 로그 | MemoryWorker, MemoryGuard 자체 종료 | CpuWorker, CPU 임계치 위반 로그 |

#### Before: RSS 증가와 MemoryGuard 종료

`runs/run-2026-09-30_19-36-55-YtfcD0/monitor.csv`의 PID 6105 행 발췌:

```csv
2026-09-30,19:36:56,6105,4.0,18488,0.1,RUNNING
2026-09-30,19:37:04,6105,1.8,95300,0.5,RUNNING
2026-09-30,19:37:14,6105,1.4,172112,1.0,RUNNING
2026-09-30,19:37:25,6105,1.4,274480,1.6,RUNNING
2026-09-30,19:37:28,6105,,,,EXITED
```

같은 실행의 `app.log`에서 환경 설정과 `Agent READY`를 확인했다. 종료 직전 원문:

```text
2026-09-30 19:37:25,131 [INFO] [MemoryWorker] Current Heap: 250MB
2026-09-30 19:37:28,186 [INFO] [MemoryWorker] Current Heap: 275MB
2026-09-30 19:37:28,186 [CRITICAL] [MemoryGuard] Memory limit exceeded (275MB >= 256MB) / (Recommend Over 256MB)
2026-09-30 19:37:28,186 [CRITICAL] [MemoryGuard] Self-terminating process 6105 to prevent system instability.
```

터미널에 launcher PID 6100의 `Killed` 메시지도 나왔지만, 이 한 단어로 OS OOM Killer 작동을 판단하지 않는다. 앱 자체 종료 로그와 PID 6105의 `EXITED`가 직접 연결된다.

#### After: RSS 정체와 다른 종료 로그

`runs/run-2026-09-30_19-37-28-bdNdQM/monitor.csv`의 PID 6311 행 발췌:

```csv
2026-09-30,19:37:29,6311,4.0,18464,0.1,RUNNING
2026-09-30,19:37:37,6311,0.8,18528,0.1,RUNNING
2026-09-30,19:37:47,6311,0.8,18528,0.1,RUNNING
2026-09-30,19:37:57,6311,1.0,18528,0.1,RUNNING
2026-09-30,19:37:59,6311,,,,EXITED
```

같은 실행의 `app.log`는 `MEMORY_LIMIT=512MB, CPU_MAX_OCCUPY=80%`와 `Agent READY`를 기록했다. 마지막 원문:

```text
2026-09-30 19:37:30,882 [INFO] [CpuWorker] Started. Maximum CPU Limit: 80%
2026-09-30 19:37:55,886 [INFO] [CpuWorker] Current Load: 46.86%
2026-09-30 19:37:58,995 [INFO] [CpuWorker] Current Load: 50.75%
2026-09-30 19:37:59,096 [CRITICAL] [CpuWorker] CPU Threshold Violated! (50.75%).
```

로그에는 80% 설정과 50.75%에서의 임계치 위반이 함께 나온다. 제공 바이너리 내부의 실제 판정 기준은 이 출력만으로 확정할 수 없다. 이 실행의 로그에는 MemoryGuard 종료나 `WATCHDOG…SIGTERM` 문구가 없다. CSV의 CPU 열은 프로세스 수명 평균이므로 앱 로그의 `Current Load`와 같은 순간 지표로 비교하지 않는다.

### 당시 원인 분석

Before의 RSS와 앱 Heap은 시간에 따라 상승했고, Heap 275MB가 설정 한계 256MB를 넘자 앱의 MemoryGuard가 PID 6105를 자체 종료한다고 기록했다. 이 실행의 종료 원인은 앱 보호 정책으로 설명된다. RSS(KiB), 앱 Heap(MB), 시스템 대비 `%MEM`은 서로 다른 지표이며, 외부 관제만으로 바이너리 내부에서 어떤 객체가 해제되지 않았는지는 단정하지 않는다.

After에서는 같은 메모리 증가 패턴이 재현되지 않았다. 앱 로그가 `CpuWorker` 시작과 임계치 위반을 기록했고 RSS는 18,464~18,528 KiB에 머물렀다. **설정 변경과 함께 관측 작업이 달라졌다는 점**은 사실이다. 왜 작업이 달라졌는지, 50.75%가 80% 설정에서 임계치 위반으로 처리된 이유와 실제 종료 신호는 로그만으로 확정하지 않는다. 이 자료를 MemoryGuard 생존 시간 개선의 인과 증거로 사용하지 않는다.

### 당시 검증 한계

임시 조치로 MEMORY_LIMIT을 256MB에서 512MB로 올렸지만 관측 시간은 **32초 → 30초**였다. Before의 MemoryGuard 종료와 After의 CpuWorker 위반은 서로 다른 종료 경로이므로, 첫 비교에서는 “메모리 한도 상향 후 더 오래 생존”을 확인할 수 없었다. 두 번의 실행·설정·로그·RSS 전후 값은 확보했다.

관측 시간은 각 CSV의 **첫 RUNNING 표본부터 EXITED 관측까지**의 차이다. 앱의 실제 시작·종료 순간과 다르고, 약 1초 간격 수집의 최고 표본 RSS도 실제 최고 사용량이 아닐 수 있다. 한도 상향 자체는 메모리 증가 원인을 제거하지 않는다.

이후 실시한 128MB→256MB 비교는 위 본문에 기록했다.
