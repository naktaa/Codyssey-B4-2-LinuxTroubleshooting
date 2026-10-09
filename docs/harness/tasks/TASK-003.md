# TASK-003: CPU 과점유 관측과 설정 전후 비교

## Goal

대상 프로세스의 CPU 급상승과 Watchdog 보호 종료를 증거로 확인하고 CPU_MAX_OCCUPY 변경 전후 종료 여부 또는 생존 시간을 비교해 CPU 보고서 1건을 작성한다.

## Context

- 사용자 “그럼 하지 말고 넘어가자. 다음 단계”로 TASK-002 실패 경로 실행 검증 생략 및 다음 CPU 단계 진행을 요청했다(2026-10-09).
- 난이도 MEDIUM, Implementer GPT-6 Sol / Medium. 기존 도구 재사용과 관측 조건·로그 해석이 필요하다.
- Review 예상 RECOMMENDED: 증거와 해석 검토. 실행·저장 기능 변경이 추가되면 실제 범위에 따라 REQUIRED로 재판정한다.
- 구현 계획 승인: 미승인. 현재는 읽기 전용 계획 단계다.
- 시작 HEAD: `e4655e3`. 시작 시 작업 트리 clean. 이후 PM 상태 기록 변경은 이번 인계에 포함한다.

## Execution State

- 현재 단계: 사용자 검증 대기. 기존 도구 사용 안내이며 source 수정 없음.
- 승인 범위: CPU 실험·비교·보고서 단계 계획. source 수정은 아직 승인되지 않았다.
- 위임: Implementer `gpt-6-sol` / `low` 기존 에이전트에 후속 읽기 전용 계획을 요청해 회수했다. 최초 실패 검증 설명에 사용한 설정이며 위 MEDIUM 추천과 구분한다. 실행 모델 메타데이터는 별도 확인하지 않았다.
- 결과 위치: 이 TASK에 회수한 계획을 기록한다.
- 다음 행동: 사용자 첫 관측 후 로그 대조. 보고서 신규 작성 계획은 실제 증거 확인 후 제시한다.

## 회수한 첫 관측 계획

- 기존 도구를 수정하지 않고 MEMORY_LIMIT=512, CPU_MAX_OCCUPY=80, MULTI_THREAD_ENABLE=false로 첫 실행한다. 이전 CpuWorker 기록과 비교하는 시작 후보이며 재현 성공을 보장하지 않는다.
- monitor CSV는 프로세스 수명 평균 CPU이므로 별도 터미널의 대상 PID `top` 관측으로 구간 변화를 보완한다. 첫 top 표본을 급상승 증거로 단정하지 않는다.
- 실제 Watchdog 로그와 종료 원인을 확인한 뒤 CPU_MAX_OCCUPY만 변경하는 두 번째 조건을 결정한다. 다른 장애가 먼저 발생하면 해당 한계를 기록한다.
- PM Review Decision: SKIP. 기존 도구의 실행 안내만 회수했으며 source 변경 없음. 후속 보고서는 증거·해석 범위를 보고 재판정한다.

## Requirements

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
