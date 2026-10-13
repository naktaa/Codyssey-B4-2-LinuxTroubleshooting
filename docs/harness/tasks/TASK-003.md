# TASK-003: CPU 과점유 관측과 설정 전후 비교

## Goal

대상 프로세스의 CPU 급상승과 Watchdog 보호 종료를 증거로 확인하고 CPU_MAX_OCCUPY 변경 전후 종료 여부 또는 생존 시간을 비교해 CPU 보고서 1건을 작성한다.

## Context

- 사용자 “그럼 하지 말고 넘어가자. 다음 단계”로 TASK-002 실패 경로 실행 검증 생략 및 다음 CPU 단계 진행을 요청했다(2026-10-09).
- 난이도 MEDIUM, Implementer GPT-6 Sol / Medium. 기존 도구 재사용과 관측 조건·로그 해석이 필요하다.
- Review 예상 RECOMMENDED: 증거와 해석 검토. 실행·저장 기능 변경이 추가되면 실제 범위에 따라 REQUIRED로 재판정한다.
- 구현 계획 승인: 2026-10-13 사용자가 아래 기존 실행 도구 인자화 계획을 승인했다.
- 시작 HEAD: `e4655e3`. 시작 시 작업 트리 clean. 이후 PM 상태 기록 변경은 이번 인계에 포함한다.

## Execution State

- 현재 단계: 사용자 검증 대기. 기존 실행 도구 인자화 구현 및 REQUIRED 독립 리뷰 완료.
- 승인 범위: [prepare-env.sh](../../../prepare-env.sh)의 메모리·CPU·멀티스레드 3개 위치 인자 지원, [메모리 비교 스크립트](../../../run-memory-comparison.sh)의 명시 인자 호출, [README](../../../README.md)의 사용법 반영. 무인자 환경변수·기본값 방식은 유지한다.
- 위임: Implementer `gpt-6-sol` / `low` 기존 에이전트에 후속 읽기 전용 계획을 요청해 회수했다. 최초 실패 검증 설명에 사용한 설정이며 위 MEDIUM 추천과 구분한다. 실행 모델 메타데이터는 별도 확인하지 않았다.
- 결과 위치: 이 TASK에 회수한 계획을 기록한다.
- 다음 행동: 사용자 인자화 실행 검증 및 512/40/false CPU 비교 관측. CPU 보고서 작성 계획은 비교 증거 확인 후 제시한다.

## 2026-10-13 인자화 승인 및 첫 관측

- 승인 근거: 사용자 “모든 필수기능을 수행할 때 저 인자 간편하게 설정 가능하다면 그렇게 수정.” 앞서 제시한 세 파일 수정 계획에 대한 승인이다.
- 인터페이스: `source ./prepare-env.sh 512 40 false`. 인자가 있으면 정확히 3개를 받아 기존 범위 검증을 적용하고, 무인자이면 기존 환경변수·기본값을 사용한다. 인자가 현재 셸의 이전 실험 설정보다 우선한다.
- 메모리 비교 함수의 위치 인자가 무인자 source에 상속되는 문제를 막기 위해 해당 호출에서 세 설정을 명시한다. 관제 도구·바이너리·기존 원본·학습 본문 변경, 신규 스크립트와 dependency 추가는 제외한다.
- 메모리·CPU·Deadlock 필수 비교에 필요한 세 환경변수 설정을 지원한다. 설정 가능 여부와 각 장애의 재현·필수 증거 확보는 별개다.
- 구현 위임: Implementer `gpt-6-sol` / `medium`, `/root/cpu_instructions`. 기준점은 HEAD `346afbb`, 승인 기록 전 작업 트리 clean. 실제 실행·테스트는 사용자 담당.
- 첫 CPU 관측: `runs/run-2026-10-13_16-29-50-Ni7K0x`의 부트 설정은 512/80/false, PID 4910. CSV 첫 RUNNING 16:29:51 → EXITED 16:30:28(37초). 앱 Current Load 5.00→50.58% 및 CPU Threshold Violated 기록. 사용자 top 캡처 16:30:12의 3.0%, 사용자 관찰 약 5%. Watchdog·SIGTERM 명시와 OS CPU 과점유 근거는 미확인이다.
- 다음 CPU 비교 후보는 512/40/false다. 별도 언급이 없으면 실행 시각이 최신인 runs 디렉터리를 찾아 실제 설정·PID와 대조한다. 원본은 Git 제외이며 보존한다.
- 구현 결과: 승인된 세 파일 변경 완료. `codyssey_prepare_env`에 위치 인자를 전달하고 0개/3개 분기와 기존 검증을 연결했다. 메모리 비교 호출은 명시 인자로 변경했다. Implementer 정적 self-check 및 PM diff 대조 완료, 실제 실행·테스트는 미수행.
- Review Decision: REQUIRED(공용 준비 도구와 메모리 비교 호출 관계 변경). 새 Reviewer `gpt-6-sol` / `medium`, `fork_turns="none"`으로 [독립 리뷰](../reviews/REVIEW-TASK-003.md) 완료. Critical/Major/Minor 없음, PM 수정 finding 없음. 인자화 검토만 완료이며 CPU 요구사항 완료를 의미하지 않는다.
- 사용자 검증: 3개 인자 실행의 부트 설정·관제 기록, 인자 개수/범위 오류 시 미실행, 기존 무인자 및 메모리 비교 호출의 회귀 여부를 확인한다. 학습 정리는 TASK 기능·사용자 검증 완료 후 수행한다.

## 회수한 첫 관측 계획

- 기존 도구를 수정하지 않고 MEMORY_LIMIT=512, CPU_MAX_OCCUPY=80, MULTI_THREAD_ENABLE=false로 첫 실행한다. 이전 CpuWorker 기록과 비교하는 시작 후보이며 재현 성공을 보장하지 않는다.
- monitor CSV는 프로세스 수명 평균 CPU이므로 별도 터미널의 대상 PID `top` 관측으로 구간 변화를 보완한다. 첫 top 표본을 급상승 증거로 단정하지 않는다.
- 실제 Watchdog 로그와 종료 원인을 확인한 뒤 CPU_MAX_OCCUPY만 변경하는 두 번째 조건을 결정한다. 다른 장애가 먼저 발생하면 해당 한계를 기록한다.
- PM Review Decision: SKIP. 기존 도구의 실행 안내만 회수했으며 source 변경 없음. 후속 보고서는 증거·해석 범위를 보고 재판정한다.

## Requirements

### 2026-10-13 두 번째 CPU 관측

- 사용자 실행 `runs/run-2026-10-13_18-05-17-HzSxJx`에서 512/40/false 인자 적용·부트 성공·PID 7167의 CSV 생성을 확인했다. 첫 RUNNING 18:05:18부터 읽은 마지막 18:07:09까지 111초 이상 RUNNING이다. 자연 종료 시간은 아니다.
- 앱은 Healthy System Monitoring을 선택했고, Current Load 40% 도달 후 cooldown과 재상승을 반복한다. Heap 525MB에서 cache cleanup·MEMORY RECOVERED를 기록했다. 첫 80% 실행과 작업 경로가 달라 동일 작업의 단순 속도 비교로 해석하지 않는다.
- 사용자는 top 약 8%를 관찰했다고 보고했다. 앱 Current Load와 OS CPU 수치는 같은 지표로 단정하지 않으며, Watchdog·SIGTERM 입증은 여전히 미완료다.
- 3개 인자 정상 적용·앱 시작·관제 수집은 이번 사용자 실행으로 확인했다. 무인자·오류 입력·메모리 비교 회귀 검증은 별도로 미확인이다.
- 사용자 kill 종료 확인 후 CSV 마지막 RUNNING 18:09:25 및 EXITED 18:09:26을 대조했다. 첫 RUNNING 18:05:18부터 종료 관측까지 248초(4분 8초)이며, 자연 종료 수명이나 Watchdog 보호 종료 시간이 아니다. 정확한 kill 옵션은 별도로 전달받지 않았다. CPU 필수 증거 누락을 유지하며 보고서 작성 계획은 이 한계를 포함해야 한다.

- [MISSION §2·§4](../MISSION.md), [REQ-003·REQ-005](../REQUIREMENTS.md): 프로세스 CPU 급상승, Watchdog 보호 종료 증거, CPU_MAX_OCCUPY 전후 비교, 네 필수 절의 CPU 보고서.
- REQ-006: CPU 과점유에 따른 지연과 관측 지표·보호 조치를 설명한다.

## Constraints

- Linux 일반 사용자, 지정 환경변수·포트 조건 및 CPU_MAX_OCCUPY 10~100 범위를 지킨다.
- 바이너리 수정·디컴파일·역공학 금지. 기존 원본을 보존하고 표준 도구를 사용한다.
- 한 비교에서는 CPU_MAX_OCCUPY만 바꾸고 다른 조건은 동일하게 기록한다.
- 실제 실행·테스트는 사용자 담당. 미션 예시 로그를 실제 증거로 사용하지 않는다.
- CPU 관측 전에 다른 장애가 발생하거나 실제 Watchdog 근거가 부족하면 한계를 기록하고 완료를 추정하지 않는다.

## Scope

- 기존 준비·관제 도구로 재현 조건과 최소 사용자 실행 절차를 계획한다.
- 사용자 원본에서 설정·PID·시각·CPU 관측·종료 원인을 연결하고 전후 비교한다.
- CPU 보고서 신규 작성과 실제 결과에 따른 README·상태 갱신, 마감 시 학습 절 작성.
- 새 자동화 스크립트나 기존 source 수정은 필요성을 제시하고 별도 구현 계획 승인을 받아야 한다.

## Out of Scope

Deadlock 본 실험, 스케줄링 보너스, TASK-002 실패 주입, 신규 프레임워크·자동 분석기, 실제 게시·제출·Git 쓰기.

## Acceptance Criteria

- [ ] 대상 PID의 CPU 급상승 구간을 관제 또는 top/ps로 확보한다.
- [ ] 실행 로그로 Watchdog 보호 종료를 입증한다.
- [ ] CPU_MAX_OCCUPY 변경 전후 종료 여부 또는 생존 시간 변화를 동일 기준으로 비교한다.
- [ ] 보고서의 현상·증거·원인·조치 및 검증 네 절을 실제 결과로 작성한다. Git 제외 원본의 핵심 근거는 출처와 함께 발췌한다.
- [ ] 필요한 리뷰·사용자 확인 및 최종 학습 정리를 완료한다. 이해 완료는 별도 확인한다.

## Relevant Files

- [prepare-env.sh](../../../prepare-env.sh), [monitor.sh](../../../monitor.sh): 재사용 우선.
- [메모리 비교 스크립트](../../../run-memory-comparison.sh), [OOM 보고서](../../reports/oom.md): 이전 실험과 한계 참고, 기존 메모리 기능 보존.
- [README](../../../README.md), [학습 노트](../../study-note.md).
- `docs/reports/cpu.md`: 신규 예정.

## Implementation Notes

기존 512MB 실행에는 CpuWorker 임계치 위반이 있지만 실제 Watchdog 신호와 내부 판정 이유는 미확인이다. 새 실험 결과를 예상하지 않는다. 관제 CPU 지표의 측정 구간과 앱 지표의 차이를 확인한다.

## Learning Deliverable

기능·리뷰·사용자 검증 후 [학습 노트](../../study-note.md)에 CPU 과점유와 시스템 지연, 관측 지표, Watchdog, 임시 조치와 전후 비교 근거를 최종 코드·실험 기준으로 정리한다.
