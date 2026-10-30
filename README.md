# Linux Troubleshooting

## 소개

제공된 `agent-leak-app`을 Linux에서 실행하고 메모리 증가·CPU 급상승·교착상태를 관측한 교육 미션. 앱 로그와 OS 수치를 근거로 장애 보고서 세 건, 선택 스케줄링 보고서 한 건 작성.

## 프로젝트 구조

| 경로 | 역할 |
| --- | --- |
| [agent-app-leak/](agent-app-leak/) | 제공된 x86·arm64 바이너리 |
| [prepare-env.sh](prepare-env.sh) | 실행 조건과 앱 시작 준비 |
| [monitor.sh](monitor.sh) | 앱 실행·관측·이번 실행 PID 정리 |
| [kill-agent-leak.sh](kill-agent-leak.sh) | 수동 확인 후 프로세스 정리 |
| `runs/` | 실행별 원본. 실행 시 생성되며 Git에서 제외 |
| [docs/harness/](docs/harness/) | 미션·요구사항·검증 이력 |

## 실행 방법

Linux 머신의 저장소 루트에서 **일반 사용자**로 실행. `MEMORY_LIMIT`은 50~512MB, `CPU_MAX_OCCUPY`는 10~100%, `MULTI_THREAD_ENABLE`은 `true/false`(`1/0`, `yes/no` 허용)이며 포트는 **15034 고정**. `AGENT_HOME`이 비어 있으면 `$HOME/agent-leak-lab` 사용. 공개 시험용 키·필수 경로는 준비 도구가 확인. 설정값 관측에는 `cc` 필요.

```bash
bash ./monitor.sh MEMORY_LIMIT CPU_MAX_OCCUPY MULTI_THREAD_ENABLE [SECONDS]
```

관측 시간은 기본 60초, 지정 시 15~300초. 다음 명령은 **현재 도구의 입력 예시**이며 아래 보고서의 과거 실행을 재수행한 기록은 아님.

```bash
bash ./monitor.sh 128 80 false 60
bash ./monitor.sh 512 40 true 60
```

각 실행의 `runs/`에 앱 로그, CSV, 스레드 표본, `observation.txt` 저장. 앱 부트 표식과 정리 전 상태·정리 결과 확인 후 다음 실행 시작. 관측 종료에 살아 있는 앱은 도구가 정리. 3·4인자 설정값 관측은 시작 시 앱 로그의 MEMORY·CPU·THREAD 검사 세 행을 원문 그대로 항목별 한 번 표시. 설정값과 앱의 `OK`/`WARNING`·권장 기준을 그대로 보여주며 로그가 없으면 정상으로 추정하지 않음. 이는 시작 설정 검사이며 실행 중 장애 판정과 구분. 종료 시점의 MemoryGuard 한도 초과·앱 내부 Load의 CPU 임계치 위반·스레드 WAITING/BLOCKED 신호와 근거 로그는 `observation.txt`에 기록하며 별도 터미널 경고는 출력하지 않음. 터미널에는 PID·관측 종료·포트 정리·최종 결과를 표시하고 시작·종료 구간은 빈 줄로 구분. WAITING/BLOCKED는 Deadlock 의심 신호이며 확정 진단은 아님. 기존 PID/CSV 단독 관제와 실패 경로는 [TASK-006](docs/harness/tasks/TASK-006.md)·[학습 노트](docs/study-note.md)에 설명.

## 주요 분석 결과

| 보고서 | 확인한 결과 | 상태 |
| --- | --- | --- |
| [OOM](docs/reports/oom.md) | CPU 40%·스레드 false에서 128/256MB는 MemoryGuard 종료(관제 17/32초), 300MB는 메모리 정리·회복 후 60초 관측까지 생존 | 메모리 비교 완료. 한도 상향은 근본 해결이 아님 |
| [CPU](docs/reports/cpu.md) | 80% 앱 임계치 위반 뒤 종료, 별도 0.1초 OS CPU 상승, 40% 설정의 60초 생존 | Watchdog 보호 종료 직접 근거가 없어 필수 요구 미완료 |
| [Deadlock](docs/reports/deadlock.md) | `true`의 A/B 락 순환 대기·작업 정체, `false`의 작업 진행 | 관측 구간 재현·회피 비교 완료 |
| [Scheduling](docs/reports/scheduling.md) | A→B→C 순차 완료 로그는 FCFS형 가설과 부합 | 선택 보너스. 실제 정책 미확정 |

세 장애 보고서의 근본 해결 항목은 **미적용 제안**. 보고서 작성과 전체 제출·사용자 학습 확인은 [요구사항](docs/harness/REQUIREMENTS.md)에서 구분.

## 관련 문서

- [미션 원문](docs/harness/MISSION.md) · [요구사항](docs/harness/REQUIREMENTS.md) · [진행 상태](docs/harness/STATUS.md)
- [실행·검증 기록](docs/harness/WORKLOG.md) · [학습 노트](docs/study-note.md) · [TASK-009](docs/harness/tasks/TASK-009.md)
