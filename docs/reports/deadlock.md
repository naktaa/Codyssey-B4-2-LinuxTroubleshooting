# [Bug] Deadlock - 두 작업 스레드의 A/B 락 순환 대기

## 1. Description (현상 설명)

2026-10-26 `512MB/CPU 40%/true` 실행에서 두 작업 스레드가 각자 A/B 락을 잡고 상대 락을 `BLOCKED`로 기다림. PID는 60초 끝까지 살아 있었으나 작업 로그가 멈췄고 스레드 CPU도 정체. 같은 조건에서 `false`로 바꾼 실행은 작업 로그가 계속 진행.

## 2. Evidence & Logs (증거 자료)

현재 재관측 입력: `bash ./monitor.sh 512 40 true 60`→정리 확인→`bash ./monitor.sh 512 40 false 60`. 아래는 기존 사용자 실행 증거.

**Before 앱 로그**

```text
2026-10-26 17:55:03,051 [INFO] [AgentWorker][Worker-Thread-1] LOCK ACQUIRED: [Shared_Memory_A]. (Holding...)
2026-10-26 17:55:03,052 [INFO] [AgentWorker][Worker-Thread-2] LOCK ACQUIRED: [Socket_Pool_B]. (Holding...)
2026-10-26 17:55:05,064 [INFO] [AgentWorker][Worker-Thread-1] WAITING for [Socket_Pool_B]... (Status: BLOCKED)
2026-10-26 17:55:05,064 [INFO] [AgentWorker][Worker-Thread-2] WAITING for [Shared_Memory_A]... (Status: BLOCKED)
```

**Before `ps -L` 기존 표본의 PID/TID/STAT/%CPU/WCHAN 열 발췌** — 15초 간격 세 표본에서 PID·스레드 유지, 두 작업 스레드 CPU 0.0%, `futex_wait` 관측. [전체 원문](../study-note.md#task-004-교착상태-관측과-멀티스레드-설정-비교)은 학습 절에 보존.

```text
    PID     TID STAT %CPU WCHAN
   9875    9875 SNl+  0.3 futex_wait
   9875    9933 SNl+  0.0 futex_wait
   9875    9934 SNl+  0.0 futex_wait
```

**After 앱 로그**

```text
2026-10-26 18:00:04,983 [INFO] [Scheduler] All tasks completed.
2026-10-26 18:00:32,072 [INFO] [CpuWorker] Peak reached (40.00%). Starting cooldown...
2026-10-26 18:01:00,146 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
```

## 3. Root Cause Analysis (원인 분석)

일반 원리상 락을 기다리는 스레드는 CPU를 계속 쓰지 않고 잠들 수 있어, CPU 사용률이 낮고 PID가 살아 있어도 작업 무응답 가능.

Thread-1은 A를 가진 채 B를, Thread-2는 B를 가진 채 A를 기다림. 로그의 반대 락 점유·요청과 반복된 OS 대기, 추가 작업 로그 부재가 순환 교착을 강하게 뒷받침.

- **상호 배제:** 각 락을 한 스레드가 점유.
- **점유 대기:** 보유한 락을 놓지 않고 다음 락 대기.
- **비선점·순환 대기:** 상대 락을 빼앗지 못한 채 A→B→A 고리 형성.

`futex_wait`나 낮은 CPU만으로 락 소유를 증명할 수 없고 내부 락 구현은 미확인.

## 4. Workaround & Verification (조치 및 검증)

임시 조치로 멀티스레드를 `true→false`로 바꾸고 메모리 512MB·CPU 40%·60초 관측을 유지했음.

| 항목 | Before: true | After: false |
| --- | --- | --- |
| PID·작업 로그 | 60초 생존, 락 대기 뒤 정체 | 60초 생존, 스케줄러 완료·후속 로그 진행 |
| 스레드/CPU | 두 작업 스레드 0.0%, 대기 지속 | 작업 진행 확인 |
| 메모리 | 증가 추세 없음(소폭 변동) | 메모리 작업에 따라 증가 |

두 실행 모두 살아 있었으므로 PID 생존만으로 정상 여부를 판정할 수 없음. `false`는 관측 구간의 회피이며 내부 락 수정이나 영구 해결이 아님. 자세한 CPU/MEM 표본은 [학습 절](../study-note.md#task-004-교착상태-관측과-멀티스레드-설정-비교)에 보존.

**근본 해결 제안(미적용):** 두 락을 항상 A→B 순서로 획득해 순환 대기를 끊는 방안 제안. 시간 제한 획득이 실패하면 보유 락을 해제한 뒤 제한된 횟수만 재시도하고, 최종 실패 시 작업 오류 보고 제안.
