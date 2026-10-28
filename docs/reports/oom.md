# [Bug] OOM Crash - MemoryGuard 종료와 메모리 한도 비교

## 1. Description (현상 설명)

`MEMORY_LIMIT=128MB`, `CPU_MAX_OCCUPY=40%`, `MULTI_THREAD_ENABLE=false`에서 앱 Heap이 150MB가 된 직후 `MemoryGuard`가 한도 초과와 자체 종료를 기록했다. 관제도 같은 PID의 `EXITED`를 기록했다. 제목의 OOM은 미션 분류이며 OS OOM Killer 작동 증거는 없다.

## 2. Evidence & Logs (증거 자료)

**Before 앱 로그**

```text
   ... MEMORY_LIMIT=128MB, CPU_MAX_OCCUPY=40%, MULTI_THREAD_ENABLE=False
 [ MEMORY ] Limit: 128MB 		[ WARNING: Recommend Over 256MB ]
 [ CPU    ] Limit: 40%  		[ OK ]
2026-10-27 21:57:32,448 [INFO] [MemoryWorker] Current Heap: 150MB
2026-10-27 21:57:32,448 [CRITICAL] [MemoryGuard] Memory limit exceeded (150MB >= 128MB) / (Recommend Over 256MB)
2026-10-27 21:57:32,448 [CRITICAL] [MemoryGuard] Self-terminating process 24966 to prevent system instability.
```

**Before 관제 CSV**

```csv
2026-10-27,21:57:16,24966,4.0,18272,0.1,RUNNING
2026-10-27,21:57:30,24966,1.4,146292,0.8,RUNNING
2026-10-27,21:57:33,24966,,,,EXITED
```

**Before 관측 요약**

```text
Observation limit: 30s
App PID state before cleanup: absent
MemoryGuard self-termination: observed — 2026-10-27 21:57:32,448 [CRITICAL] [MemoryGuard] Self-terminating process 24966 to prevent system instability.
```

## 3. Root Cause Analysis (원인 분석)

관제 RSS가 19MB에서 150MB 표본으로 증가하고 앱 Heap이 150MB로 설정 한계를 넘은 직후 `MemoryGuard`가 관제 PID와 같은 프로세스의 자체 종료를 기록했다. 이는 앱의 메모리 한도 보호 동작을 뒷받침한다.

RSS, 앱 Heap, 시스템 대비 `%MEM`은 서로 다른 지표다. 바이너리 내부의 미해제 객체나 OS OOM Killer 작동은 확인하지 못했다.

## 4. Workaround & Verification (조치 및 검증)

공통 `monitor.sh`를 사용하고 CPU 40%·스레드 false를 유지하면서 `MEMORY_LIMIT`을 128MB에서 300MB로 올렸다. After는 부트 메모리 검사 `[ OK ]`를 통과해 다른 작업 경로인 `Healthy System Monitoring`으로 진행했다. Heap 300MB에서 `MemoryWorker` 정리 경고가 있었고 캐시 비우기·메모리 회복을 기록했다.

| 항목 | Before: 128MB | After: 300MB |
| --- | --- | --- |
| 공통 설정 | CPU 40%, 스레드 false | CPU 40%, 스레드 false |
| 도구 관측 상한 | 30초 | 60초 |
| 공통 첫 30초 구간 | 첫 `RUNNING` 뒤 17초에 `EXITED` | 30초 시점에 `RUNNING` |
| 전체 관측 종료 시점 | 앱 종료 확인 | 60초 끝에도 `RUNNING`; 이후 도구가 앱 정리 |
| 관제 RSS 시작 → 최고 표본 | 19 → 150MB | 19 → 307MB |
| 정리 직후 → 마지막 RSS | 해당 없음 | 19 → 202MB |
| 앱 결과 | Heap 150MB, `MemoryGuard` 자체 종료 | Heap 300MB, `MemoryWorker` 정리 후 회복; `MemoryGuard` 종료 기록 없음 |

RSS 표의 정수 MB는 관제 원값 KiB에 1,024를 곱하고 1,000,000바이트=1MB로 환산해 반올림했다. 앱 Heap의 MB는 앱이 기록한 별도 값이다. 두 실행 모두 CPU 자원 검사는 `[ OK ]`였고 CPU 임계치 위반 기록은 없다.

**After 앱 로그**

```text
   ... MEMORY_LIMIT=300MB, CPU_MAX_OCCUPY=40%, MULTI_THREAD_ENABLE=False
 [ MEMORY ] Limit: 300MB 		[ OK ]
 [ CPU    ] Limit: 40%  		[ OK ]
2026-10-28 16:29:40,236 [INFO] >>> Scenario Selected: [Healthy System Monitoring]
2026-10-28 16:30:14,652 [INFO] [MemoryWorker] Current Heap: 300MB
2026-10-28 16:30:14,652 [WARNING] [MemoryWorker] Memory Usage Reached Limit (300MB). Starting cleanup...
2026-10-28 16:30:14,659 [INFO] [System] Memory Cache Flushed. Process Stabilized.
>>> [SYSTEM] MEMORY RECOVERED (Cache Cleared) <<<
2026-10-28 16:30:19,681 [INFO] [MemoryWorker] Current Heap: 25MB
```

**After 관제 CSV**

```csv
2026-10-28,16:29:39,8176,4.0,18220,0.1,RUNNING
2026-10-28,16:30:09,8176,2.2,274556,1.6,RUNNING
2026-10-28,16:30:14,8176,2.0,300160,1.8,RUNNING
2026-10-28,16:30:15,8176,2.1,18516,0.1,RUNNING
2026-10-28,16:30:39,8176,1.7,197732,1.2,RUNNING
```

**After 관측 요약**

```text
Observation limit: 60s
App PID state before cleanup: SNl+
App was present at the observation cutoff; later tool cleanup is separate.
MemoryGuard self-termination: no matching line found
Tool cleanup status: 0
```

128MB 실행은 첫 `RUNNING`부터 17초 뒤 `EXITED`였고 300MB 실행은 공통 첫 30초와 전체 60초 관측 끝에도 살아 있었다. 이후 종료 상태는 도구의 정리 동작에 따른 것으로 앱 자체 종료가 아니다. 작업 경로와 관측 상한이 달라 한도 상향의 인과적 생존 효과나 근본 해결을 입증하지 않는다.

관제 시각은 표본 시각이므로 실제 시작·종료 순간과 차이가 있고 최고 RSS 표본이 실제 최고 사용량이라는 보장도 없다.
