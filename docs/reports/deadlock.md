# [Bug] Deadlock - 두 작업 스레드의 A/B 락 순환 대기

## 1. Description (현상 설명)

2026-10-26 사용자 실행에서 `MEMORY_LIMIT=512MB`, `CPU_MAX_OCCUPY=40%`, `MULTI_THREAD_ENABLE=true`로 부트에 성공했다. 두 작업 스레드는 서로 다른 락을 확보한 뒤 상대 락을 `WAITING ... BLOCKED`로 기록했고, 이후 앱 로그의 작업 진행이 멈췄다. 프로세스는 60초 관측 끝까지 살아 있었다.

## 2. Evidence & Logs (증거 자료)

앱 로그의 마지막 핵심 기록은 Thread-1의 `WAITING for [Socket_Pool_B]... (Status: BLOCKED)`와 Thread-2의 `WAITING for [Shared_Memory_A]... (Status: BLOCKED)`다. 앞선 `LOCK ACQUIRED` 기록은 각각 Thread-1의 `Shared_Memory_A`, Thread-2의 `Socket_Pool_B` 점유를 보여 준다. 작업 정체 뒤 15초 간격으로 수집한 `ps -L` 세 표본에서는 PID 9875와 스레드가 계속 존재했고, 세 스레드 모두 `futex_wait`, 두 작업 스레드의 `%CPU`는 각각 0.0%였다. 앱 로그도 같은 마지막 기록에 머물렀다.

**Before 앱 로그**

```text
2026-10-26 17:55:03,051 [INFO] [AgentWorker][Worker-Thread-1] LOCK ACQUIRED: [Shared_Memory_A]. (Holding...)
2026-10-26 17:55:03,052 [INFO] [AgentWorker][Worker-Thread-2] LOCK ACQUIRED: [Socket_Pool_B]. (Holding...)
2026-10-26 17:55:05,064 [INFO] [AgentWorker][Worker-Thread-1] WAITING for [Socket_Pool_B]... (Status: BLOCKED)
2026-10-26 17:55:05,064 [INFO] [AgentWorker][Worker-Thread-2] WAITING for [Shared_Memory_A]... (Status: BLOCKED)
```

**Before ps**

```text
    PID     TID STAT %CPU   RSS WCHAN                    COMMAND
   9875    9875 SNl+  0.3 18440 futex_wait               agent-leak-app-
   9875    9933 SNl+  0.0 18440 futex_wait               agent-leak-app-
   9875    9934 SNl+  0.0 18440 futex_wait               agent-leak-app-
```

**Before 관제**

```text
2026-10-26,17:54:56,9875,4.0,18352,0.1,RUNNING
2026-10-26,17:55:56,9875,0.0,18148,0.1,RUNNING
```

Before 관제 RSS는 처음과 마지막 표본에서 모두 약 19MB였다. 원문 표본에는 소폭 변동이 있어 완전한 불변은 아니다.

## 3. Root Cause Analysis (원인 분석)

Thread-1은 A를 가진 채 B를, Thread-2는 B를 가진 채 A를 기다린다. 로그의 반대 락 점유·요청 순서, 반복된 OS 대기 상태, 추가 작업 로그 부재를 함께 보면 순환 대기로 인한 교착이 강하게 추론된다. 락을 가진 채 상대 락을 기다리고 임의로 빼앗지 못하는 구조라 다음 작업으로 나아가지 못한다.

`futex_wait`와 낮은 CPU만으로 락 소유자나 교착을 증명할 수는 없다. 앱 스레드 이름과 OS TID의 개별 대응, 바이너리 내부의 정확한 락·해제 구현도 확인하지 못했다.

## 4. Workaround & Verification (조치 및 검증)

사용자는 true 앱 종료와 포트 해제 후, `MEMORY_LIMIT=512MB`, `CPU_MAX_OCCUPY=40%` 및 60초 관측을 유지하고 `MULTI_THREAD_ENABLE=false`로 다시 실행했다.

| 항목 | Before: true | After: false |
| --- | --- | --- |
| 고정 조건 | 메모리 512MB, CPU 40%, 관측 60초 | 동일 |
| 앱 로그 | Thread-1: A 확보→B `BLOCKED`; Thread-2: B 확보→A `BLOCKED` | `Healthy System Monitoring`; 스케줄러 완료, 메모리 작업·CPU cooldown 진행 |
| 관제 상태 | 60초 끝까지 `RUNNING`, 로그 정체 | 60초 끝까지 `RUNNING`, 로그 지속 |
| 관제 RSS 처음→마지막 | 19→19MB, 중간 최고도 19MB | 19→517MB |
| 관제 수명평균 CPU 처음→마지막 | 4.0→0.0% | 5.0→1.8% |

**After 앱 로그**

```text
2026-10-26 18:00:04,983 [INFO] [Scheduler] All tasks completed.
2026-10-26 18:00:17,241 [INFO] [MemoryWorker] Current Heap: 125MB
2026-10-26 18:00:32,072 [INFO] [CpuWorker] Peak reached (40.00%). Starting cooldown...
2026-10-26 18:00:47,775 [INFO] [MemoryWorker] Current Heap: 375MB
2026-10-26 18:01:00,146 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
```

**After 관제**

```text
2026-10-26,18:00:03,10481,5.0,18500,0.1,RUNNING
2026-10-26,18:01:02,10481,1.8,504780,3.0,RUNNING
```

관제 원문의 RSS는 KiB이며, 표의 정수 MB는 이를 바이트로 환산해 1,000,000바이트=1MB 기준으로 반올림했다. 앱 Heap MB와는 다른 지표다. false는 같은 60초 동안 작업 완료와 후속 로그가 이어져 해당 구간의 교착을 회피했다. 두 실행 모두 PID가 살아 있었으므로 생존 자체는 정상 작업의 증거가 아니다.

설정 변경으로 앱 경로도 달라졌다. 이 결과는 관측 구간의 회피 효과이며 같은 락 구현의 수정이나 영구적인 무장애를 증명하지 않는다. false의 RSS 증가는 별도의 자원 사용 추이로 남는다.
