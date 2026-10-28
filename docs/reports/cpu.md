# [Bug] CPU Latency - 앱 임계치 위반과 CPU 설정 비교

> 상태: 앱 임계치 위반 직후 종료와 설정 전후 상태를 관측했다. 새 0.1초 OS 표본에서는 대상 프로세스의 순간 CPU 상승도 확인했다. 지속적인 과점유·시스템 지연과 Watchdog 보호 종료는 입증하지 못해 CPU 미션의 필수 증거가 남아 있다.

## 1. Description (현상 설명)

2026-10-27 사용자 실행에서 `MEMORY_LIMIT=512MB`, `CPU_MAX_OCCUPY=80%`, `MULTI_THREAD_ENABLE=false`로 부트 검사를 통과했다. `CpuWorker`의 앱 지표 `Current Load`가 53.08%에 이른 뒤 `CPU Threshold Violated!`가 기록되고 다음 관제 표본에서 프로세스가 `EXITED`였다. 이 실행의 1초 간격 `top` 표본에서는 OS CPU 급상승을 확인하지 못했다.

2026-10-28 같은 설정의 별도 실행에서는 대상 프로세스의 약 0.1초 OS CPU 구간 사용률이 앱 `Current Load` 상승과 가까운 시각에 45.94%, 54.41%로 관측됐다. 이어 앱 로그에 임계치 위반이 기록됐고 관제에는 `EXITED`가 남았다. 이는 짧은 구간의 대상 프로세스 CPU 상승을 보여 주지만 Watchdog 보호 종료나 시스템 지연을 입증하지는 않는다.

## 2. Evidence & Logs (증거 자료)

**Before 앱 로그**

```text
   ... MEMORY_LIMIT=512MB, CPU_MAX_OCCUPY=80%, MULTI_THREAD_ENABLE=False
2026-10-27 16:00:14,557 [INFO] [CpuWorker] Current Load: 53.08%
2026-10-27 16:00:14,658 [CRITICAL] [CpuWorker] CPU Threshold Violated! (53.08%).
```

**Before 관제**

```text
2026-10-27,15:59:45,4283,4.0,18240,0.1,RUNNING
2026-10-27,16:00:14,4283,0.9,18304,0.1,RUNNING
2026-10-27,16:00:15,4283,,,,EXITED
```

**Before top**

```text
2026-10-27 16:00:11 KST,27,0,4283,5.0,0:00.28
2026-10-27 16:00:14 KST,30,0,4283,4.0,0:00.32
```

`top`의 Before 구간 최대치는 첫 프레임을 제외하면 5%다. 관제 CPU 값은 프로세스 수명 평균이므로 순간 부하와 구분한다.

**추가 80% 실행: 앱 로그와 동일 PID의 OS CPU 구간 표본**

```text
앱 로그       2026-10-28 23:16:15,826 [INFO] [CpuWorker] Current Load: 45.50%
0.1초 CPU CSV "2026-10-28 23:16:15,915",90266,35.30,0.10,45.94,S,
앱 로그       2026-10-28 23:16:18,946 [INFO] [CpuWorker] Current Load: 53.71%
0.1초 CPU CSV "2026-10-28 23:16:19,015",90266,38.40,0.10,54.41,S,54.41
앱 로그       2026-10-28 23:16:19,048 [CRITICAL] [CpuWorker] CPU Threshold Violated! (53.71000000000001%).
관제 CSV      2026-10-28,23:16:19,90266,,,,EXITED
```

같은 실행의 별도 1초 CPU CSV에는 `"2026-10-28 23:16:16,515",90266,35.90,1.10,4.19,S,4.19`, 관제 CSV에는 `2026-10-28,23:16:16,90266,0.8,18412,0.1,RUNNING`이 기록됐다. 약 0.1초의 짧은 사용률 상승은 더 긴 구간의 값에 희석될 수 있다. 0.1초·1초 값은 서로 다른 측정 구간이며 관제 CPU 값은 프로세스 시작 이후 평균이다.

두 CPU CSV의 `cpu_percent_interval`은 앱 PID의 프로세스 CPU 시간 증가량을 해당 표본의 실제 경과 시간으로 나눈 값으로, 한 코어 사용률을 100%로 표시한다. `interval_s`는 실제 구간을 소수점 둘째 자리까지 표시한다. 1초 CSV는 약 1초 구간을 별도로 계산하므로 0.1초 수치의 단순 평균이 아니다. `group_percent_sum`은 연속 양수 표본의 단순 합계일 뿐 OS CPU 사용률이 아니므로 위 근거에는 사용하지 않는다.

## 3. Root Cause Analysis (원인 분석)

앱 지표 상승, 임계치 위반, 프로세스 종료 순서는 앱의 보호 동작 가능성을 시사한다. 새 OS 표본의 순간 상승은 같은 시각대 대상 PID의 CPU 사용을 뒷받침한다. 그러나 근접한 시각과 수치만으로 앱 `Current Load`와 OS 구간 사용률의 계산 대상·방법이 동일하거나 한 값이 다른 값의 원인이라고 판단할 수 없다. 이를 설정 한도 소진율로 취급할 수도 없으며, 80% 설정에서 약 50%의 앱 지표로 위반된 이유도 확정할 수 없다.

기록에는 Watchdog 조치, `SIGTERM` 발신자, 시스템 지연의 측정값이 없다. 새 0.1초 표본은 짧은 CPU 상승을 보여 주지만 지속적인 과점유나 종료 주체를 입증하지 않는다. 앞선 1초 간격 `top` 표본은 낮은 값이었으며, 서로 다른 구간의 값으로 앱 내부 판정식이나 Watchdog 동작을 역산할 수 없다.

## 4. Workaround & Verification (조치 및 검증)

`MEMORY_LIMIT=512MB`, `MULTI_THREAD_ENABLE=false`를 유지하고 `CPU_MAX_OCCUPY`를 80%에서 40%로 바꿨다. After는 부트 검사를 통과하고 `Healthy System Monitoring` 경로에서 40% 피크와 cooldown을 기록했다.

| 항목 | Before: 80% | After: 40% |
| --- | --- | --- |
| 앱 로그 | `Current Load: 53.08%` → `CPU Threshold Violated!` | `Peak reached (40.00%). Starting cooldown...` → `Cooldown complete (5.00%). Resuming load increase...` |
| 관제 | 첫 `RUNNING` 후 30초에 `EXITED` | 60초 마지막 표본까지 `RUNNING` |
| 자식 프로세스 `top` 구간 표본 최대 `%CPU` | 5% | 8% |

**After 앱 로그**

```text
   ... MEMORY_LIMIT=512MB, CPU_MAX_OCCUPY=40%, MULTI_THREAD_ENABLE=False
2026-10-27 16:13:44,078 [INFO] >>> Scenario Selected: [Healthy System Monitoring]
2026-10-27 16:14:08,837 [INFO] [CpuWorker] Peak reached (40.00%). Starting cooldown...
2026-10-27 16:14:33,798 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
```

**After 관제**

```text
2026-10-27,16:13:42,5484,5.0,18340,0.1,RUNNING
2026-10-27,16:14:42,5484,2.0,505048,3.0,RUNNING
```

**After top**

```text
2026-10-27 16:14:07 KST,25,0,5484,8.0,0:00.53
2026-10-27 16:14:43 KST,61,0,5484,4.0,0:01.26
```

`top`의 구간 최대치는 첫 프레임을 제외한 값이다. `top`의 `%CPU`는 OS 표본이며 앱 `Current Load`와 같은 지표로 환산하지 않는다. 80% 실행은 첫 `RUNNING` 후 30초에 종료가 관측됐고 40% 실행은 60초 관측 종료 시점에도 생존했다. 설정 변경과 함께 앱 작업 경로도 달라져 같은 작업의 CPU 완화 효과나 자연 생존 시간 연장을 증명하지 않는다. 60초는 관측 종료 시점이며 앱의 자연 종료 시각이 아니다.

앞선 80%·추가 90% 실행에서도 앱 지표 약 50~52% 뒤 임계치 위반과 종료가 반복됐지만 OS CPU 급상승은 입증되지 않았다. 90% 실행은 메모리 설정도 달라 이번 비교의 통제된 After 증거로 사용하지 않는다.

2026-10-28 추가 80% 실행의 0.1초 OS 표본은 위 2026-10-27 Before와 수집법이 다르다. 40% After에는 같은 0.1초 수집 결과가 없으므로 새 수치를 설정 전후의 OS CPU 감소량이나 완화 효과로 비교하지 않는다.
