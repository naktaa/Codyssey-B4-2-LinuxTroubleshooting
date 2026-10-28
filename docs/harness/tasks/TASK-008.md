# TASK-008: 공통 관측 스크립트 정리

## Goal

세 장애를 [monitor.sh](../../../monitor.sh)의 설정값 명령 하나로 관측하고, 쓰지 않는 실행 진입점을 정리하며, `observation.txt`에는 판정에 필요한 요약만 남긴다.

## Approval and Scope

- 사용자는 삭제 대상 6개와 요약·문서 정리의 영향을 설명받은 뒤 “진행”으로 승인했다.
- 삭제: `observe.sh`, `observe-memory.sh`, `run-cpu-observation.sh`, `run-deadlock-observation.sh`, `memory-test.sh`, `run-memory-comparison.sh`.
- 수정: [monitor.sh](../../../monitor.sh)의 요약 출력, [README](../../../README.md)의 현재 실행 안내, [학습 노트](../../study-note.md)와 과거 TASK·리뷰·[WORKLOG](../WORKLOG.md)의 삭제 파일 링크 표기.
- [prepare-env.sh](../../../prepare-env.sh), [kill-agent-leak.sh](../../../kill-agent-leak.sh), 기존 실행 기록과 보고서는 보존한다. `monitor.sh`의 2인자 PID/CSV 수집 경로도 유지한다.

## Implementation and Review

- Implementer는 6개 파일을 삭제하고, 반복 CSV·CPU·스레드 발췌를 `observation.txt`에서 제거했다. 설정·PID 식별값, 정리 전 앱 상태, 수집 상태, 앱 로그 신호, 정리·포트 결과는 남겼다. README는 현재 실행을 `monitor.sh` 기준으로 바꿨다.
- 삭제 파일을 향하는 Markdown 링크는 과거 사실을 유지하면서 당시 파일명을 글자로 표시했다. 기존 `runs/` 내용은 수정하지 않았다.
- 정적 확인: `bash -n`(남은 셸 파일), `git diff --check`, 삭제 대상 링크·현재 명령 검색. 실제 앱 실행은 사용자가 담당하며 새 요약 출력·정리 결과의 실행 검증은 대기한다.
- Review Decision: REQUIRED. 삭제에 따른 실행 호환성과 문서 영향이 있어 독립 [리뷰](../reviews/REVIEW-TASK-008.md)를 수행했다. Critical 0, Major 0, Minor 1이다.
- Minor-1은 [TASK-005](TASK-005.md)의 당시 “다음 행동”을 현행 과제로 오인할 여지다. 당시 계획의 역사 기록은 유지하고, [STATUS](../STATUS.md)와 README의 현행 `monitor.sh` 안내로 현재 실행 경로를 확인한다. 과거 TASK 본문의 추가 교정은 이번 승인 범위에서 보류한다.

## Acceptance Criteria

- [x] 현재 세 장애 관측의 실행 명령을 `monitor.sh`로 통일한다.
- [x] 불필요한 실행 진입점 6개를 제거하고 남은 내부 의존 스크립트를 유지한다.
- [x] 새 `observation.txt`의 중복 표본을 제거하고 정리 전후 상태를 보존한다.
- [x] README의 현재 명령과 삭제 파일을 향하는 Markdown 링크를 정리한다.
- [ ] 사용자가 새 형식의 실제 실행 결과와 종료 후 프로세스·포트 상태를 확인한다.
