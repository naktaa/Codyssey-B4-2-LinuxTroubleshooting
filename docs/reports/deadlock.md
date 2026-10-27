# [Bug] Deadlock — 두 작업 스레드의 A/B 락 순환 대기

> 상태: 교착 재현·설정 변경 후 회피 비교, 독립 리뷰·사용자 확인·최종 학습 정리 완료(2026-10-27). 로그와 OS 관측을 종합한 원인 추론이며, 바이너리 내부 락 구현은 확인하지 않았다. 별도 관측 도구의 신호·실패 경로 실행 검증은 미확인으로 남긴다.

## 1. Description (현상 설명)

2026-10-26 Linux 일반 사용자 환경에서 `MEMORY_LIMIT=512MB`, `CPU_MAX_OCCUPY=40%`, `MULTI_THREAD_ENABLE=true`로 부트 검사에 성공했다. 자식 PID 9875는 살아 있었지만, 두 작업 스레드가 각각 자원을 확보한 뒤 17:55:05.064에 상대 자원을 `WAITING ... BLOCKED`로 기록하고 앱 로그 진행이 멈췄다. 이후 반복 OS 표본에서도 스레드들이 대기를 유지했다.

같은 메모리·CPU 설정과 기본 60초 관측을 유지하고 `MULTI_THREAD_ENABLE=false`로 바꾸자, 자식 PID 10481은 `Healthy System Monitoring` 경로에서 작업 완료·메모리 작업·CPU 부하 조절 로그를 계속 남겼다. 두 실행 모두 관측 종료까지 PID가 생존했으므로, PID 존재만으로 정상 작업 여부를 구분할 수 없었다.

## 2. Evidence & Logs (증거 자료)

사용자가 repository 루트에서 실행한 명령은 다음과 같다. 각 실행의 기본 관측 설정은 60초, 프로세스·스레드 표본은 15초 간격 네 번이다. 사용자는 true 앱을 종료하고 포트 해제를 확인한 뒤 false 실행을 진행했다고 확인했다. AI는 앱을 실행하거나 종료하지 않았다.

```bash
bash ./run-deadlock-observation.sh 512 40 true
bash ./run-deadlock-observation.sh 512 40 false
```

두 명령은 각기 별도의 실행이며 연속 실행을 위한 자동 종료 명령이 아니다. [관측 스크립트](../../run-deadlock-observation.sh)는 관측 시간이 끝나면 자신이 시작한 CSV 관제를 정리하고 앱은 유지한다.

원본은 아래 네 파일씩을 대조했다. `runs/`는 Git 제외 대상이므로 다른 작업 공간에서는 링크가 열리지 않을 수 있어 핵심 원문과 수치를 본문에도 남긴다.

| 설정 | 원본 |
| --- | --- |
| true · 261026-175455_512_40_true-kFiIRQ | [app.log](../../runs/261026-175455_512_40_true-kFiIRQ/app.log), [agent_app.log](../../runs/261026-175455_512_40_true-kFiIRQ/agent_app.log), [monitor.csv](../../runs/261026-175455_512_40_true-kFiIRQ/monitor.csv), [thread-observation.txt](../../runs/261026-175455_512_40_true-kFiIRQ/thread-observation.txt) |
| false · 261026-180002_512_40_false-1munWl | [app.log](../../runs/261026-180002_512_40_false-1munWl/app.log), [agent_app.log](../../runs/261026-180002_512_40_false-1munWl/agent_app.log), [monitor.csv](../../runs/261026-180002_512_40_false-1munWl/monitor.csv), [thread-observation.txt](../../runs/261026-180002_512_40_false-1munWl/thread-observation.txt) |

두 실행의 `app.log`에는 `All Boot Checks Passed!`와 `Agent READY`가 있다. 설정·PID·수집 시각은 다음과 같다. 시각은 로컬 KST이며 수집 시작·마지막 표본 시각은 프로세스 생성·종료 시각이 아니다.

| 항목 | true | false |
| --- | --- | --- |
| launch_local | 17:54:55 | 18:00:02 |
| MEMORY_LIMIT / CPU_MAX_OCCUPY | 512MB / 40% | 512MB / 40% |
| 자식 PID / launcher PID | 9875 / 9870 | 10481 / 10476 |
| 설정한 관측 시간 | 60초 | 60초 |
| CSV 첫 표본~마지막 표본 | 17:54:56~17:55:56 | 18:00:03~18:01:02 |
| CSV 상태 | 전 행 RUNNING | 전 행 RUNNING |

### true: 락 점유와 마지막 대기 로그

`agent_app.log`에서 발췌했다. `Shared_Memory_A`와 `Socket_Pool_B`는 앱 로그에 나온 자원 명칭이며, 실제 메모리·소켓 구현을 조사해 확인한 이름은 아니다.

```text
2026-10-26 17:55:03,052 [INFO] [AgentWorker][Worker-Thread-2] LOCK ACQUIRED: [Socket_Pool_B]. (Holding...)
2026-10-26 17:55:03,051 [INFO] [AgentWorker][Worker-Thread-1] LOCK ACQUIRED: [Shared_Memory_A]. (Holding...)
2026-10-26 17:55:05,063 [INFO] [AgentWorker][Worker-Thread-1] Need resource [Socket_Pool_B] to finish job.
2026-10-26 17:55:05,064 [INFO] [AgentWorker][Worker-Thread-1] WAITING for [Socket_Pool_B]... (Status: BLOCKED)
2026-10-26 17:55:05,063 [INFO] [AgentWorker][Worker-Thread-2] Need resource [Shared_Memory_A] to write logs.
2026-10-26 17:55:05,064 [INFO] [AgentWorker][Worker-Thread-2] WAITING for [Shared_Memory_A]... (Status: BLOCKED)
```

17:55:11·26·41의 관측 파일에서 마지막 로그 8줄이 동일했다. 현재 true 앱 로그도 위 두 BLOCKED 기록에서 끝난다. 같은 시각의 프로세스·스레드 표본은 다음과 같다.

| 관측 시각 / 경과 | PID 9875 수명평균 CPU | RSS (KiB) | 스레드 상태 |
| --- | --- | --- | --- |
| 17:54:56 / 약 0초 | 4.0% | 18,352 | 메인 TID 9875: do_select |
| 17:55:11 / 약 15초 | 0.3% | 18,440 | TID 9875/9933/9934: 모두 futex_wait |
| 17:55:26 / 약 30초 | 0.1% | 18,440 | 같은 세 TID: 모두 futex_wait |
| 17:55:41 / 약 45초 | 0.1% | 18,148 | 같은 세 TID: 모두 futex_wait |

뒤 세 표본에서 TID 9933/9934의 CPU 표시는 각각 0.0%였다. 원본 `ps -L` 표 일부는 다음과 같다.

```text
    PID     TID STAT %CPU   RSS WCHAN                    COMMAND
   9875    9875 SNl+  0.3 18440 futex_wait               agent-leak-app-
   9875    9933 SNl+  0.0 18440 futex_wait               agent-leak-app-
   9875    9934 SNl+  0.0 18440 futex_wait               agent-leak-app-
```

CSV 마지막 표본까지 PID는 RUNNING이었고 수명평균 CPU는 4.0%에서 0.0%로 감소했다. RSS는 초기 증가 후 약 18MiB 범위에 머물렀지만 17:55:41부터 18,440→18,148KiB로 소폭 감소했으므로 완전히 불변이라고 표현하지 않는다.

### false: 같은 시간 간격에서 작업 진행

`agent_app.log`에는 18:00:04.212 `Scenario Selected: [Healthy System Monitoring]`, 18:00:04.983 `[Scheduler] All tasks completed.`가 있다. 이후 메모리 작업과 CPU 부하 조절이 계속됐다.

```text
2026-10-26 18:00:17,241 [INFO] [MemoryWorker] Current Heap: 125MB
2026-10-26 18:00:32,072 [INFO] [CpuWorker] Peak reached (40.00%). Starting cooldown...
2026-10-26 18:00:47,775 [INFO] [MemoryWorker] Current Heap: 375MB
2026-10-26 18:01:00,146 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
```

| 관측 시각 / 경과 | PID 10481 수명평균 CPU | RSS (KiB) | 스레드 상태 |
| --- | --- | --- | --- |
| 18:00:03 / 약 0초 | 5.0% | 18,500 | 메인 TID 10481: do_select |
| 18:00:18 / 약 15초 | 1.9% | 146,816 | 메인: futex_wait; TID 10512/10513: do_select |
| 18:00:33 / 약 30초 | 2.0% | 274,836 | 메인: futex_wait; TID 10512: do_select, 10513: R·wchan '-' |
| 18:00:48 / 약 45초 | 2.0% | 402,856 | 메인: futex_wait; TID 10512/10513: do_select |

CSV 마지막 18:01:02에는 RSS 504,780KiB, 수명평균 CPU 1.8%, RUNNING이 기록됐다. 마지막 로그 발췌도 각 표본마다 달라 작업 진행을 확인할 수 있다. `false`에서도 OS 스레드가 존재하고 메인 스레드가 `futex_wait`를 보이므로, 이 설정을 OS 수준의 완전한 단일 스레드 전환으로 설명하거나 메인의 대기만으로 교착이라고 판단하지 않는다.

두 실행의 CSV `cpu_percent_lifetime`과 `ps`의 `%CPU`는 프로세스·스레드 수명 동안의 평균이다. 앱 `CpuWorker`의 `Current Load`와 같은 지표로 환산하지 않으며, 스레드 행의 RSS를 더해 프로세스 메모리로 계산하지 않는다.

## 3. Root Cause Analysis (원인 분석)

로그상 서로 반대 순서로 락을 획득하려는 흐름과 이후 작업 정체가 교착상태의 원인으로 추론된다. 점유·요청 관계는 다음과 같다.

| 작업 스레드 | 먼저 획득한 락 | 이후 기다리는 락 | 그 락을 먼저 획득한 상대 |
| --- | --- | --- | --- |
| Worker-Thread-1 | Shared_Memory_A | Socket_Pool_B | Worker-Thread-2 |
| Worker-Thread-2 | Socket_Pool_B | Shared_Memory_A | Worker-Thread-1 |

Thread-1은 A를 보유한 채 B가 필요하고 Thread-2는 B를 보유한 채 A가 필요하다. 상대 락을 얻지 못해 다음 처리로 나아가지 못하고, 기존 락의 해제로 이어질 진행도 막힌 구조로 해석할 수 있다. 이 점유와 순환 대기에 반복된 OS 대기·로그 정체가 더해져 교착상태 재현을 뒷받침한다.

교착상태의 네 조건으로 설명하면 락의 독점 사용은 상호 배제, 락을 가진 채 추가 락을 기다리는 것은 점유 대기, 다른 스레드의 락을 임의로 회수하지 못하는 것은 비선점, 서로의 락을 기다리는 고리는 순환 대기다. 다만 바이너리 내부의 락 함수·해제 위치·타임아웃·강제 회수 정책은 확인하지 않았으므로, 네 조건의 세부 구현까지 검증했다고 주장하지 않는다.

락 대기 상태에서는 계산이 진행되지 않아 CPU 사용이 낮을 수 있다. 대기는 종료가 아니므로 PID와 이미 확보한 메모리가 남을 수 있고, 후속 처리에 도달하지 못하면 새 로그도 멈춘다. `futex_wait`는 동기화 대기의 OS 관측값이며 락 소유자나 교착을 단독으로 증명하지 않는다. 앱의 로그 스레드 이름과 TID 9933/9934 사이의 개별 대응도 확인하지 않았다. 메인 스레드가 작업 완료를 기다린다는 앱 로그는 있지만 정확한 내부 대기 함수는 알 수 없다.

## 4. Workaround & Verification (조치 및 검증)

조치는 메모리·CPU 인자와 기본 관측 시간을 유지하고 `MULTI_THREAD_ENABLE`만 true에서 false로 바꾼 것이다. 사용자 확인에 따르면 true 실행을 종료하고 포트를 비운 후 false를 실행했다. 각 실행의 관측 명령 반환값은 0이었고, 종료 출력에서 자식·launcher PID와 15034 포트의 생존을 확인했다는 [TASK-004 기록](../harness/tasks/TASK-004.md)을 함께 근거로 사용한다. 반환값 0은 관측 수집의 정상 완료이며 앱이 정상 작업 중이라는 판정 자체는 아니다.

| 항목 | Before: true | After: false |
| --- | --- | --- |
| 고정 조건 | 512MB / CPU 40% / 기본 60초 | 동일 |
| 앱 경로 | concurrent transaction processors | Healthy System Monitoring |
| 작업·로그 진행 | A/B 락 점유 후 17:55:05.064 BLOCKED, 이후 정체 | 스케줄러 완료, 메모리 작업·CPU cooldown/재상승 진행 |
| OS 스레드 관측 | 뒤 세 표본의 세 TID 모두 futex_wait | 메인 대기 중에도 다른 TID의 대기·실행과 작업 진행 관측 |
| CSV 처음→마지막 RSS | 18,352→18,148KiB; 중간 18,440KiB | 18,500→504,780KiB |
| CSV 처음→마지막 수명평균 CPU | 4.0→0.0% | 5.0→1.8% |
| 마지막 CSV 상태 | RUNNING | RUNNING |
| 결론 | 순환 대기·작업 정체로 교착 재현 추론 | 해당 관측 구간에서 교착 회피·작업 진행 확인 |

설정 변경으로 앱의 작업 경로 자체가 달라졌다. 따라서 이 결과는 이번 설정·관측 구간에서의 회피 효과이며, 같은 락 알고리즘을 수정했다거나 모든 조건에서 영구적으로 장애가 없음을 입증하지 않는다. false의 RSS 증가도 있으므로 이를 모든 자원 문제가 해결된 결과로 확대하지 않는다.

false 앱 로그는 CSV 종료 뒤에도 이어졌다. 특히 18:01:06.063의 `Memory Usage Reached Limit (525MB). Starting cleanup...`와 18:01:06.074의 `Memory Cache Flushed. Process Stabilized.`는 18:01:02 마지막 CSV보다 뒤의 추가 로그다. 이 cleanup을 60초 비교 구간에서 RSS 감소를 검증한 결과로 섞지 않는다.

관측 도구의 시간 만료 후 관제 정리·앱 유지 경로는 두 사용자 실행에서 확인됐다. Ctrl+C/TERM 중단 코드, 자연 종료, 관제 오류와 종료 요청의 경합은 실제 실행 검증이 남아 있으며, 이번 비교 결과로 검증됐다고 기록하지 않는다. 이는 관측 도구의 별도 미검증 범위이며 위 교착 진단과 설정 비교의 근거를 대체하지 않는다.
