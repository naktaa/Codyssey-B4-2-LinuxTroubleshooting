# [Bug] OOM Crash - MemoryGuard 종료와 메모리 한도 비교

## 1. Description (현상 설명)

2026-10-30 Linux 일반 사용자 실행에서 CPU 40%·멀티스레드 false를 유지하고 `MEMORY_LIMIT`을 128→256→300MB로 조정. 128/256MB는 Heap 150/275MB에서 각각 `MemoryGuard` 자체 종료. 300MB는 앱의 메모리 정리·회복 후 60초 관측까지 생존. 세 실행 모두 부트 CPU 검사 `OK`, CPU 임계치 위반 로그 없음. 제목의 OOM은 미션 분류이며 OS OOM Killer 작동 확인은 없음.

## 2. Evidence & Logs (증거 자료)

- 동일 설정 관측 명령: `bash ./monitor.sh 128 40 false`, `bash ./monitor.sh 256 40 false`, `bash ./monitor.sh 300 40 false`(기본 관측 60초). 각 실행의 정리 후 다음 실행 진행.
- 세 실행 모두 부트 검사 통과 및 `Agent READY` 확인. 앱 로그·관제 PID 대조.
- 원본 폴더: [128MB](../../runs/261030-163840_128_40_false-WOdHCR), [256MB](../../runs/261030-164017_256_40_false-uYJCQ5), [300MB](../../runs/261030-164059_300_40_false-7BDsAR). `runs/`는 Git에서 제외되므로 아래에 핵심 행 발췌.

**Before: 128MB, PID 5307**

```text
2026-10-30 16:38:57,765 [INFO] [MemoryWorker] Current Heap: 150MB
2026-10-30 16:38:57,765 [CRITICAL] [MemoryGuard] Memory limit exceeded (150MB >= 128MB) / (Recommend Over 256MB)
2026-10-30 16:38:57,765 [CRITICAL] [MemoryGuard] Self-terminating process 5307 to prevent system instability.
```

```csv
2026-10-30,16:38:41,5307,2.0,18344,0.1,RUNNING
2026-10-30,16:38:57,5307,1.1,146364,0.8,RUNNING
2026-10-30,16:38:58,5307,,,,EXITED
```

**After: 256MB, PID 5570**

```text
2026-10-30 16:40:50,572 [INFO] [MemoryWorker] Current Heap: 275MB
2026-10-30 16:40:50,572 [CRITICAL] [MemoryGuard] Memory limit exceeded (275MB >= 256MB) / (Recommend Over 256MB)
2026-10-30 16:40:50,572 [CRITICAL] [MemoryGuard] Self-terminating process 5570 to prevent system instability.
```

```csv
2026-10-30,16:40:19,5570,4.0,18328,0.1,RUNNING
2026-10-30,16:40:50,5570,1.2,274368,1.6,RUNNING
2026-10-30,16:40:51,5570,,,,EXITED
```

**After: 300MB, PID 5953**

```text
2026-10-30 16:41:36,036 [WARNING] [MemoryWorker] Memory Usage Reached Limit (300MB). Starting cleanup...
2026-10-30 16:41:36,043 [INFO] [System] Memory Cache Flushed. Process Stabilized.
>>> [SYSTEM] MEMORY RECOVERED (Cache Cleared) <<<
2026-10-30 16:41:41,074 [INFO] [MemoryWorker] Current Heap: 25MB
```

```csv
2026-10-30,16:41:00,5953,5.0,18220,0.1,RUNNING
2026-10-30,16:41:35,5953,2.1,300136,1.8,RUNNING
2026-10-30,16:41:37,5953,2.2,18492,0.1,RUNNING
2026-10-30,16:42:00,5953,1.9,197708,1.2,RUNNING
```

## 3. Root Cause Analysis (원인 분석)

일반 원리상 프로세스는 가상 주소 공간의 힙 등에 동적 데이터를 보관하며, RSS는 현재 물리 메모리에 상주한 프로세스 페이지의 크기. 앱의 자체 Heap 지표와 RSS는 범위·단위·측정 시점이 달라 같은 값으로 해석할 수 없음.

128/256MB 실행에서 RSS와 앱 Heap 증가 후 한도 초과. 직후의 `MemoryGuard` 자체 종료 로그와 동일 PID의 `EXITED`로 종료 경로 확인. 내부 미해제 객체와 OS OOM Killer 작동은 외부 기록만으로 미확인.

앱 권장 문구는 `Recommend Over 256MB`이며 275MB는 256MB 설정에서 종료 시 Heap. 300MB 설정은 메모리 검사 `OK`와 `Healthy System Monitoring` 경로를 기록하고 메모리 정리·회복 수행. CPU 설정은 세 실행에서 같지만 앱 작업 경로가 달라, 동일 작업에서 메모리 한도만 높인 효과나 내부 분기 원인을 입증한 것으로 해석하지 않음.

## 4. Workaround & Verification (조치 및 검증)

임시 조치로 메모리 한도를 128→256MB로 높이면 같은 증가 작업에서 첫 `RUNNING`부터 `EXITED` 관측까지 17→32초로 늘었으나 **두 실행 모두 종료**. 300MB에서는 정리·회복 후 60초 관측까지 생존해 이후 도구가 정리함.

| 항목 | Before: 128MB | After: 256MB | After: 300MB |
| --- | --- | --- | --- |
| 고정 조건 | CPU 40%, 멀티스레드 false | 동일 | 동일 |
| RSS 시작→최고 표본 | 19→150MB | 19→281MB | 19→307MB |
| 앱 Heap·결과 | 150MB, MemoryGuard 자체 종료 | 275MB, MemoryGuard 자체 종료 | 300→25MB 정리·회복, 이후 다시 증가 |
| 관제 구간 | 16:38:41→16:38:58, **17초** | 16:40:19→16:40:51, **32초** (+15초) | 16:41:00→16:42:00, **60초까지 RUNNING** |
| 종료·정리 | 관측 중 앱 종료 | 관측 중 앱 종료 | 컷오프 생존 후 도구 정리 |

RSS 요약은 원문 KiB×1,024÷1,000,000을 정수 반올림한 MB(1MB=1,000,000바이트). 시간은 관제 표본 사이 간격이며 실제 프로세스 수명은 아님. 300MB 실행의 RSS는 정리 전 307MB(16:41:35)→정리 후 19MB(16:41:37)로 감소.

세 실행 모두 `Tool cleanup status: 0`, 포트 15034 해제 및 최종 PID 부재 기록. 300MB 실행은 `monitor CSV status=143`, `CPU CSV status=0`이므로 수집 전체 정상 완료로 판정하지 않음. 마지막 CSV의 `RUNNING`과 정리 전 앱 상태 `SNl+`로 컷오프 생존은 확인. 관측 구간의 회복이며 영구 해결은 미확인.

**근본 해결 제안(미적용):** 객체·캐시의 수명 점검, 사용 후 참조 해제, 누적 버퍼·큐의 상한 설정 제안. 동일 작업량의 Heap·RSS와 종료 여부를 재관측 후 효과 판단 필요.
