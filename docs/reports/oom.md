# [Bug] OOM Crash - MemoryGuard 종료와 메모리 한도 비교

## 1. Description (현상 설명)

2026-09-30 Linux 일반 사용자 비교에서 CPU 80%·멀티스레드 false를 유지하고 `MEMORY_LIMIT`만 128→256MB로 조정. 두 실행에서 동일한 `MemoryWorker` 증가 작업 뒤 Heap 150/275MB에서 각각 `MemoryGuard` 자체 종료 기록. 제목의 OOM은 미션 분류이며 OS OOM Killer 작동 확인은 없음.

## 2. Evidence & Logs (증거 자료)

- 당시 사용자 비교 스크립트(현재 삭제)로 128MB와 256MB를 순차 실행. 현재 재관측은 `bash ./monitor.sh 128 80 false 60`→정리 확인→`bash ./monitor.sh 256 80 false 60` 입력 가능하나 이 원본의 재실행은 아님.
- 두 실행 모두 부트 검사 통과 및 `Agent READY` 확인.
- 앱 종료 로그의 PID와 관제 PID가 각각 일치함.
- 아래는 당시 사용자 실행 원문 중 핵심 행. `runs/` 원본은 Git에서 제외됨.

**Before: 128MB, PID 8661**

```text
2026-09-30 20:12:51,096 [INFO] [MemoryWorker] Current Heap: 150MB
2026-09-30 20:12:51,096 [CRITICAL] [MemoryGuard] Memory limit exceeded (150MB >= 128MB) / (Recommend Over 256MB)
2026-09-30 20:12:51,096 [CRITICAL] [MemoryGuard] Self-terminating process 8661 to prevent system instability.
```

```csv
2026-09-30,20:12:34,8661,5.0,18500,0.1,RUNNING
2026-09-30,20:12:48,8661,1.4,146520,0.8,RUNNING
2026-09-30,20:12:51,8661,,,,EXITED
```

**After: 256MB, PID 8790**

```text
2026-09-30 20:13:24,469 [INFO] [MemoryWorker] Current Heap: 275MB
2026-09-30 20:13:24,470 [CRITICAL] [MemoryGuard] Memory limit exceeded (275MB >= 256MB) / (Recommend Over 256MB)
2026-09-30 20:13:24,470 [CRITICAL] [MemoryGuard] Self-terminating process 8790 to prevent system instability.
```

```csv
2026-09-30,20:12:52,8790,4.0,18588,0.1,RUNNING
2026-09-30,20:13:22,8790,1.1,274628,1.6,RUNNING
2026-09-30,20:13:25,8790,,,,EXITED
```

## 3. Root Cause Analysis (원인 분석)

일반 원리상 프로세스는 가상 주소 공간의 힙 등에 동적 데이터를 보관하며, RSS는 현재 물리 메모리에 상주한 프로세스 페이지의 크기. 앱의 자체 Heap 지표와 RSS는 범위·단위·측정 시점이 달라 같은 값으로 해석할 수 없음.

두 실행에서 물리 메모리 점유 표본(RSS)이 증가했고 앱 Heap도 설정 한도 초과. 한도 초과 직후의 `MemoryGuard` 자체 종료 로그와 동일 PID의 `EXITED`로 종료 경로 확인. 내부 미해제 객체와 OS OOM Killer 작동은 외부 기록만으로 미확인.

## 4. Workaround & Verification (조치 및 검증)

임시 조치로 메모리 한도를 128→256MB로 높였음. 같은 증가 작업에서 첫 `RUNNING`부터 `EXITED` 관측까지 17→33초로 늘었으나, **두 실행 모두 종료**됐음.

| 항목 | Before: 128MB | After: 256MB |
| --- | --- | --- |
| 고정 조건 | CPU 80%, 멀티스레드 false | 동일 |
| RSS 시작→최고 표본 | 19→150MB | 19→281MB |
| 앱 Heap·종료 | 150MB, MemoryGuard 자체 종료 | 275MB, MemoryGuard 자체 종료 |
| 첫 `RUNNING`→`EXITED` | 20:12:34→20:12:51, **17초** | 20:12:52→20:13:25, **33초** (+16초) |

RSS 요약은 원문 KiB×1,024÷1,000,000을 정수 반올림한 MB(1MB=1,000,000바이트). 시간은 관제 표본 사이 간격이며 실제 프로세스 수명은 아님.

**후속 300MB 별도 관측:** 앱 권장 문구는 `Recommend Over 256MB`이며, 위 275MB는 256MB 설정에서 종료 시 Heap. 권장치를 넘긴 2026-10-28 `300/40/false` 실행(PID 8176)은 메모리 검사 `OK`와 `Healthy System Monitoring` 경로 기록. 이후 앱의 메모리 정리·회복 관측.

```text
2026-10-28 16:30:14,652 [WARNING] [MemoryWorker] Memory Usage Reached Limit (300MB). Starting cleanup...
2026-10-28 16:30:14,659 [INFO] [System] Memory Cache Flushed. Process Stabilized.
>>> [SYSTEM] MEMORY RECOVERED (Cache Cleared) <<<
2026-10-28 16:30:19,681 [INFO] [MemoryWorker] Current Heap: 25MB
```

| 지표 | 정리 전 | 정리 후 |
| --- | --- | --- |
| 앱 Heap | 300MB (16:30:14) | 25MB (16:30:19) |
| RSS 표본 | 307MB (16:30:14) | 19MB (16:30:15) |

60초 컷오프까지 `RUNNING` 유지, 이후 도구가 정리했음. 기존 주 비교와 CPU 설정·작업 경로가 달라 한도만의 인과 효과·내부 분기 원인·영구 해결은 미확인. 전체 원문은 [학습 노트의 별도 이력](../study-note.md#후속-128300mb-관측-이력-현재-보고서의-주-비교와-별개)에 보존.

**근본 해결 제안(미적용):** 객체·캐시의 수명 점검, 사용 후 참조 해제, 누적 버퍼·큐의 상한 설정 제안. 동일 작업량의 Heap·RSS와 종료 여부를 재관측 후 효과 판단 필요.
