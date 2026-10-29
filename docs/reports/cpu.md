# [Bug] CPU Latency - 임계치 위반 뒤 앱 자체 종료로 해석

## 1. Description (현상 설명)

2026-10-27 `512MB/CPU 80%/false` 실행에서 앱 `Current Load: 53.08%` 뒤 `CPU Threshold Violated!`가 발생했고 같은 PID의 `EXITED` 관측. 별도 2026-10-28 실행에서는 대상 PID의 짧은 OS CPU 상승 45.94%·54.41% 포착. 앱 자체 보호 종료로 해석하지만 CPU 필수 요구는 미완료.

## 2. Evidence & Logs (증거 자료)

- 현재 재관측 입력: `bash ./monitor.sh 512 80 false 60`→정리 확인→`bash ./monitor.sh 512 40 false 60`. 아래는 이전 사용자 실행 증거.
- Before 80%: 앱 임계치 위반→동일 PID 종료 관측.
- 추가 80%: 앱 로그와 가까운 시각의 별도 0.1초 OS 표본 상승 확인.
- After 40%: `Healthy System Monitoring`에서 40% 피크·cooldown 뒤 60초 관측 끝에도 생존.

**Before 앱 로그·관제**

```text
2026-10-27 16:00:14,557 [INFO] [CpuWorker] Current Load: 53.08%
2026-10-27 16:00:14,658 [CRITICAL] [CpuWorker] CPU Threshold Violated! (53.08%).
```

```csv
2026-10-27,15:59:45,4283,4.0,18240,0.1,RUNNING
2026-10-27,16:00:15,4283,,,,EXITED
```

**별도 80% 실행: 앱 로그·OS 구간 표본·관제**

```text
앱 로그       2026-10-28 23:16:15,826 [INFO] [CpuWorker] Current Load: 45.50%
0.1초 CPU CSV "2026-10-28 23:16:15,915",90266,35.30,0.10,45.94,S,
앱 로그       2026-10-28 23:16:18,946 [INFO] [CpuWorker] Current Load: 53.71%
0.1초 CPU CSV "2026-10-28 23:16:19,015",90266,38.40,0.10,54.41,S,54.41
앱 로그       2026-10-28 23:16:19,048 [CRITICAL] [CpuWorker] CPU Threshold Violated! (53.71000000000001%).
관제 CSV      2026-10-28,23:16:19,90266,,,,EXITED
```

같은 추가 실행의 별도 약 1초 구간은 `4.19%`였음. 0.1초 표본의 평균이나 40% After와의 동일 방식 비교값은 아님.

**After 앱 로그·관제**

```text
2026-10-27 16:13:44,078 [INFO] >>> Scenario Selected: [Healthy System Monitoring]
2026-10-27 16:14:08,837 [INFO] [CpuWorker] Peak reached (40.00%). Starting cooldown...
2026-10-27 16:14:33,798 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
```

```csv
2026-10-27,16:13:42,5484,5.0,18340,0.1,RUNNING
2026-10-27,16:14:42,5484,2.0,505048,3.0,RUNNING
```

## 3. Root Cause Analysis (원인 분석)

일반 원리상 짧은 CPU burst는 대기·휴식 구간을 포함하는 긴 측정창의 평균에서 낮게 나타날 수 있음. CPU를 요구하는 작업이 경쟁하면 실행 대기가 늘어 응답이 지연될 수 있으나, 이번 실행의 실제 경쟁·지연은 미측정.

OS 구간 CPU는 해당 PID의 CPU 시간 증가량을 실제 경과 시간으로 나눈 비율이며 한 코어를 계속 사용하면 100% 기준. 앱 `Current Load`는 내부 지표이고 OS 0.1초·1초 구간 CPU 및 관제의 수명 평균 CPU와 다른 값. 임계치 위반 뒤 `EXITED` 순서는 앱 자체 보호 종료를 시사. Watchdog 조치·`SIGTERM` 발신자·시스템 지연은 직접 기록되지 않아 원문의 보호 종료와 지속 과점유까지 입증 불가.

## 4. Workaround & Verification (조치 및 검증)

임시 조치로 CPU 설정을 80→40%로 바꾸고 메모리 512MB·멀티스레드 false를 유지했음.

| 항목 | Before: 80% | After: 40% |
| --- | --- | --- |
| 앱 로그 | `Current Load: 53.08%`→임계치 위반 | 40% 피크→cooldown 완료 |
| 관제 | 첫 `RUNNING` 뒤 30초에 `EXITED` | 60초 컷오프까지 `RUNNING`, 이후 도구 정리 |
| 당시 자식 `top` 구간 최대 | 5% | 8% |

설정 변경과 함께 앱 작업 경로도 달라졌음. 별도 0.1초 상승은 40% After의 OS CPU 감소 효과로 비교할 수 없음.

**근본 해결 제안(미적용):** 긴 CPU burst를 작은 작업으로 나누고 단위 시간당 작업량·동시 실행 수 제한 제안. 작업 사이 대기·스케줄링 간격 조정은 동일 작업량의 구간 CPU·응답 지연을 재측정 후 판단 필요.
