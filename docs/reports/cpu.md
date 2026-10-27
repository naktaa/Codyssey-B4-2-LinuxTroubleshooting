# [Bug] CpuWorker 임계치 위반과 CPU 설정 비교

> 상태: CPU 보고서 초안. 앱 자체 부하 상승과 임계치 위반 직후 종료는 관측했으나, 대상 프로세스의 OS CPU 과점유와 Watchdog 보호 종료는 입증하지 못했다. 따라서 CPU 미션의 필수 증거는 아직 미충족이다.

## 1. Description (현상 설명)

2026-10-26 Linux 일반 사용자 실행에서 `MEMORY_LIMIT=512MB`, `CPU_MAX_OCCUPY=80%`, `MULTI_THREAD_ENABLE=false`로 부트 검사 6개를 통과했다. 자식 프로세스 PID 5286의 `CpuWorker`가 기록한 `Current Load`는 5.00%에서 50.42%까지 올랐고, 16:02:27.864에 `CPU Threshold Violated!`를 기록했다. 관제는 다음 초에 PID의 `EXITED`를 기록했다. 임계치 위반과 종료가 연달아 발생한 점은 앱의 보호 동작에 따른 종료를 시사하지만, 제공 로그에는 Watchdog 동작이나 종료 신호의 발신자가 명시되지 않았다.

2026-10-27 같은 설정 중 `CPU_MAX_OCCUPY`만 80%와 40%로 달리한 두 실행을 추가로 관측했다. 80%에서는 앱 지표가 53.08%에 이르러 임계치 위반을 기록한 직후 자식 PID 4283의 종료가 관제되었다. 40%에서는 앱이 `Healthy System Monitoring` 경로를 선택해 40% 피크와 cooldown을 기록했고, 자식 PID 5484가 60초 관측 끝까지 살아 있었다. 두 실행의 앱 작업 경로가 달라 이 결과만으로 CPU 과점유 방지 효과를 입증할 수 없다.

## 2. Evidence & Logs (증거 자료)

이번 실행 원본: [app.log](../../runs/run-2026-10-26_16-01-54-2PYjC0/app.log), [agent_app.log](../../runs/run-2026-10-26_16-01-54-2PYjC0/agent_app.log), [monitor.csv](../../runs/run-2026-10-26_16-01-54-2PYjC0/monitor.csv), [top.log](../../runs/run-2026-10-26_16-01-54-2PYjC0/top.log). 네 파일을 확인했다. `runs/`는 Git 제외 대상이므로 다른 작업 공간에서는 링크가 열리지 않을 수 있다. 핵심 원문을 아래에 발췌한다.

`app.log`의 설정·부트 기록:

```text
launch_local=2026-10-26 16:01:54
   ... MEMORY_LIMIT=512MB, CPU_MAX_OCCUPY=80%, MULTI_THREAD_ENABLE=False
All Boot Checks Passed!
Agent READY
```

`agent_app.log`의 앱 지표와 마지막 기록:

```text
2026-10-26 16:01:56,526 [INFO] [CpuWorker] Started. Maximum CPU Limit: 80%
2026-10-26 16:01:56,526 [INFO] [CpuWorker] Current Load: 5.00%
2026-10-26 16:02:15,264 [INFO] [CpuWorker] Current Load: 38.45%
2026-10-26 16:02:24,636 [INFO] [CpuWorker] Current Load: 49.20%
2026-10-26 16:02:27,762 [INFO] [CpuWorker] Current Load: 50.42%
2026-10-26 16:02:27,864 [CRITICAL] [CpuWorker] CPU Threshold Violated! (50.419999999999995%).
```

`monitor.csv`의 같은 PID 시작·종료 표본:

```csv
2026-10-26,16:02:01,5286,0.8,18548,0.1,RUNNING
2026-10-26,16:02:27,5286,1.0,18548,0.1,RUNNING
2026-10-26,16:02:28,5286,,,,EXITED
```

첫 `RUNNING`부터 `EXITED` 관측까지 27초다. `launch_local`부터 `EXITED` 관측까지는 약 34초이며, 시작 후 약 7초는 CSV 수집 전이다. 두 시간 모두 실제 프로세스 종료 순간의 정밀 측정값은 아니다. CSV의 `cpu_percent_lifetime`은 `ps`가 제공하는 프로세스 시작 이후 평균이다.

`top.log`의 PID 5286 행 일부:

```text
top - 16:02:02
   5286 nakta     30  10   29764  18548   9956 S   0.0   0.1   0:00.07 agent-leak-app-
top - 16:02:19
   5286 nakta     30  10   29764  18548   9956 S   5.0   0.1   0:00.25 agent-leak-app-
top - 16:02:27
   5286 nakta     30  10   29764  18548   9956 S   0.0   0.1   0:00.34 agent-leak-app-
```

16:02:02~16:02:27의 대상 PID 행 26개에서 `top`의 `%CPU`는 0~5%였다. 같은 구간 `TIME+`는 0:00.07에서 0:00.34로, 약 25초 동안 누적 CPU 시간은 약 0.27초 늘었다. 이는 이 PID의 OS CPU 과점유를 보여 주지 않는다. 16:02:28 이후 `top`은 대상 PID 없이 계속 기록했으므로 뒤쪽의 시스템 전체 `%Cpu(s)`나 다른 표본을 PID 5286 사용률로 읽지 않는다. 이 실행 당시 `top`의 Irix/Solaris 표시 모드는 원본에서 확인할 수 없다. 이후 확인한 머신의 CPU 6개와 `top`의 Irix On 표시가 이번 과거 표본의 표시 모드를 증명하지는 않는다.

### 2026-10-27 동일 입력의 80%·40% 관측

80% 실행 원본: [app.log](../../runs/run-2026-10-27_15-59-44-5osiuy/app.log), [agent_app.log](../../runs/run-2026-10-27_15-59-44-5osiuy/agent_app.log), [monitor.csv](../../runs/run-2026-10-27_15-59-44-5osiuy/monitor.csv), [top-scope.csv](../../runs/run-2026-10-27_15-59-44-5osiuy/top-scope.csv), [process-scope.log](../../runs/run-2026-10-27_15-59-44-5osiuy/process-scope.log).

40% 실행 원본: [app.log](../../runs/run-2026-10-27_16-13-41-binP1r/app.log), [agent_app.log](../../runs/run-2026-10-27_16-13-41-binP1r/agent_app.log), [monitor.csv](../../runs/run-2026-10-27_16-13-41-binP1r/monitor.csv), [top-scope.csv](../../runs/run-2026-10-27_16-13-41-binP1r/top-scope.csv), [process-scope.log](../../runs/run-2026-10-27_16-13-41-binP1r/process-scope.log). 두 실행의 각 다섯 파일을 대조했다. `runs/`는 Git 제외 대상이므로 다른 작업 공간에서는 링크가 열리지 않을 수 있다.

두 `app.log`의 설정과 앱 지표 발췌(주석은 실행 구분):

```text
# 80% 실행
launch_local=2026-10-27 15:59:44
   ... MEMORY_LIMIT=512MB, CPU_MAX_OCCUPY=80%, MULTI_THREAD_ENABLE=False
All Boot Checks Passed!
2026-10-27 16:00:14,557 [INFO] [CpuWorker] Current Load: 53.08%
2026-10-27 16:00:14,658 [CRITICAL] [CpuWorker] CPU Threshold Violated! (53.08%).

# 40% 실행
launch_local=2026-10-27 16:13:41
   ... MEMORY_LIMIT=512MB, CPU_MAX_OCCUPY=40%, MULTI_THREAD_ENABLE=False
All Boot Checks Passed!
2026-10-27 16:13:44,078 [INFO] >>> Scenario Selected: [Healthy System Monitoring]
2026-10-27 16:14:08,837 [INFO] [CpuWorker] Peak reached (40.00%). Starting cooldown...
2026-10-27 16:14:09,839 [INFO] [CpuWorker] Current Load: 40.00%
2026-10-27 16:14:33,798 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
```

두 `process-scope.log`의 PID·PPID·시작 시각은 80%에서 실행기 4278 → 자식 4283, 40%에서 실행기 5479 → 자식 5484를 보여 준다. 각각의 `monitor.csv`와 `top-scope.csv`도 이 자식 PID를 추적한다. 종료·생존 경계의 원문 발췌(주석은 파일 구분):

```text
# 80% monitor.csv
2026-10-27,15:59:45,4283,4.0,18240,0.1,RUNNING
2026-10-27,16:00:14,4283,0.9,18304,0.1,RUNNING
2026-10-27,16:00:15,4283,,,,EXITED
# 80% top-scope.csv
2026-10-27 15:59:45 KST,1,1,4283,0.0,0:00.04
2026-10-27 16:00:11 KST,27,0,4283,5.0,0:00.28
2026-10-27 16:00:14 KST,30,0,4283,4.0,0:00.32

# 40% monitor.csv
2026-10-27,16:13:42,5484,5.0,18340,0.1,RUNNING
2026-10-27,16:14:42,5484,2.0,505048,3.0,RUNNING
# 40% top-scope.csv
2026-10-27 16:13:43 KST,1,1,5484,0.0,0:00.05
2026-10-27 16:14:07 KST,25,0,5484,8.0,0:00.53
2026-10-27 16:14:43 KST,61,0,5484,4.0,0:01.26
```

80%의 첫 CSV `RUNNING` 15:59:45부터 `EXITED` 관측 16:00:15까지는 30초, `launch_local`부터는 약 31초다. 자식의 `top` 행은 15:59:45~16:00:14에 존재하며, 첫 프레임을 뺀 구간 표본에서 최대 5%, 누적 CPU 시간 0.04→0.32초(29초에 0.28초 증가)다. 40%의 CSV는 16:13:42~16:14:42 내내 `RUNNING`이고, `top`은 16:13:43~16:14:43의 60초 끝에도 실행기와 자식을 보여 준다. 자식의 첫 프레임을 뺀 `top` 구간 표본 최대는 8%, 누적 CPU 시간은 0.05→1.26초(60초에 1.21초 증가)다. `process-scope.log`도 각 시각의 부모·자식 관계와 40% 마지막 프레임의 생존을 뒷받침한다. `monitor.csv`의 CPU 백분율은 프로세스 수명 평균이며, `top-scope.csv` 첫 프레임은 구간 비교에서 제외한다. 60초 관측 종료는 40% 앱의 자연 종료가 아니다.

40% 앱의 첫 메모리 정리 기록은 16:14:45.944로 마지막 `top` 프레임 16:14:43과 마지막 CSV `RUNNING` 16:14:42 뒤에 발생했다. `agent_app.log`에도 이 후속 기록이 있지만 60초 CPU 관측 구간 안의 사건으로 세지 않는다.

## 3. Root Cause Analysis (원인 분석)

앱 로그는 `CpuWorker`의 `Current Load` 상승과 임계치 위반을 직접 보여 준다. 직후 PID가 사라진 순서는 보호 동작 가능성을 뒷받침한다. 다만 `Current Load`의 내부 계산식과 측정 대상은 제공된 소스·문서에 정의되지 않았다. 따라서 이를 `top`의 프로세스 `%CPU`, 시스템 전체 CPU 사용률 또는 `CPU_MAX_OCCUPY` 소진율과 같은 값으로 환산하지 않는다. 설정은 80%인데 50.42%에서 임계치 위반이 기록된 이유도 외부 로그만으로 확정할 수 없다.

`app.log`와 `agent_app.log`에는 Watchdog의 조치, `SIGTERM` 또는 신호 발신자를 설명하는 기록이 없다. 미션의 `WATCHDOG… SIGTERM`은 예시 문구이므로 글자 그대로의 일치가 필수인 것은 아니다. 그러나 현재 기록만으로 해당 종료가 Watchdog의 시스템 보호 조치였다고 확정할 수 없다. 사용자 셸의 `Terminated` 출력도 종료 관측 근거일 뿐 발신자나 정책의 증거는 아니다. 이 실행에서 시스템 지연이 발생했는지도 측정하지 않았다.

2026-10-27의 두 실행도 앱의 `Current Load`가 무엇을 측정하고 어떻게 계산되는지 밝히지 못한다. 80% 설정에서 53.08%에 임계치 위반이 기록된 이유를 외부 기록만으로 설명할 수 없다. 두 자식 PID의 OS `%CPU` 표본은 낮은 범위였고 프로세스 CPU 급상승·시스템 지연을 입증하지 않는다. 80%의 임계치 위반 직후 종료는 확인되지만 Watchdog·`SIGTERM`·종료 신호 발신자는 두 실행 로그에 명시되지 않았다. 40%의 `Peak reached`와 cooldown은 앱 내부 경로의 기록이지 OS CPU 과점유 완화의 직접 증거가 아니다.

## 4. Workaround & Verification (조치 및 검증)

기존 2026-10-13 비교에서는 `CPU_MAX_OCCUPY`를 80%에서 40%로 바꾸고 `MEMORY_LIMIT=512MB`, `MULTI_THREAD_ENABLE=false`를 유지했다. 아래 40% 결과는 [TASK-003 기록](../harness/tasks/TASK-003.md)과 [WORKLOG](../harness/WORKLOG.md)에 근거한다. 그 실행의 `runs/` 원본은 현재 작업 공간에 없으므로 이번 80% 실행처럼 재대조하지 못했다.

| 항목 | 80% 실행 | 40% 실행 |
| --- | --- | --- |
| 기록 시기와 자식 PID | 2026-10-26, PID 5286 | 2026-10-13, PID 7167 |
| 앱 작업 | `CpuWorker`, 임계치 위반 기록 | `Healthy System Monitoring`, 40%에서 cooldown·재상승 기록 |
| 관제 시간 | 첫 RUNNING→EXITED 27초; launch→EXITED 약 34초 | 첫 RUNNING→사용자 kill 후 EXITED 248초 |
| 종료 해석 | 임계치 위반 직후 종료 관측; 보호 동작 가능성, Watchdog 미입증 | 사용자가 수동 종료; 자연 종료 시간 아님 |

이 표는 설정과 관측 결과의 차이를 보여 주지만, 앱 작업 경로가 다르고 40% 실행은 사용자가 종료했으므로 같은 작업의 자연 생존 시간 향상이나 CPU 과점유 방지 효과로 단정할 수 없다. `CPU_MAX_OCCUPY=40%`는 이 자료에서 해결책으로 검증된 값이 아니다.

2026-10-27에는 `MEMORY_LIMIT=512MB`, `MULTI_THREAD_ENABLE=false`를 고정하고 `CPU_MAX_OCCUPY`만 바꾼 별도 비교도 확보했다.

| 항목 | 80% 실행 | 40% 실행 |
| --- | --- | --- |
| 실행 시각·PID | 15:59:44 시작; 실행기 4278, 자식 4283 | 16:13:41 시작; 실행기 5479, 자식 5484 |
| 앱 경로 | `CpuWorker` 임계치 위반 | `Healthy System Monitoring`; 40% 피크·cooldown |
| 같은 60초 관측 안의 상태 | CSV 16:00:15 `EXITED`; 첫 `RUNNING` 이후 30초 | CSV 마지막 16:14:42 `RUNNING`, top 마지막 16:14:43에도 PID 존재 |
| 자식의 OS CPU 표본 | 첫 프레임 제외 `top` 최대 5%; CPU 시간 0.04→0.32초 | 첫 프레임 제외 `top` 최대 8%; CPU 시간 0.05→1.26초 |

확인된 차이는 80% 실행의 조기 종료 관측과 40% 실행의 60초 구간 생존이다. 40% 관측 도구의 반환값 0은 사용자 제공 실행 결과로, 앱의 종료 코드나 이후 자연 생존 시간을 뜻하지 않는다. 앱 경로가 달라 동일 작업의 성능 개선이나 `CPU_MAX_OCCUPY` 변경만의 인과 효과를 결론 내리지 않는다. `CPU_MAX_OCCUPY=40%`를 검증된 해결책으로 제시하지 않는다.

남은 필수 증거는 대상 프로세스의 OS CPU 급상승 구간과 Watchdog 보호 종료 근거다. 추가 관측을 한다면 동일 실행의 PID·시각·앱 로그·OS CPU 표본을 연결하고, 종료 직후 로그에서 보호 조치의 명시적 설명을 확인해야 한다. 재실행만으로 그 결과가 보장되지는 않는다. 확인 전까지 이 보고서와 CPU TASK는 미완료로 유지한다.
