# Review: TASK-008 — 공통 관측 스크립트 정리

- 대상: [TASK-008](../tasks/TASK-008.md), [MISSION](../MISSION.md) §2·§4 및 [REQUIREMENTS](../REQUIREMENTS.md) REQ-002~004.
- 기준점·범위: 현재 작업 트리의 HEAD 대비 변경을 독립적으로 확인했다. 삭제된 `observe.sh`, `observe-memory.sh`, `run-cpu-observation.sh`, `run-deadlock-observation.sh`, `memory-test.sh`, `run-memory-comparison.sh`, [monitor.sh](../../../monitor.sh), [README](../../../README.md), 변경된 과거 TASK·리뷰·[WORKLOG](../WORKLOG.md)·[학습 노트](../../study-note.md)의 관련 부분을 검토했다. 과거 기록의 삭제 대상은 파일명과 “삭제 전” 표시로 구분한다.
- 독립성·한계: 구현 대화를 상속하지 않았다. 앱·스크립트·테스트는 실행하지 않았으며, 실제 경합·파일 쓰기 실패·포트 정리 결과를 검증하지 않았다. `rg`로 삭제 대상 호출과 링크 잔존을 확인했다. `git diff --check`는 추적 파일 변경에 대해 통과했고, 신규 리뷰 문서는 `rg`로 행 끝 공백을 별도로 확인했다. Markdown 전체 링크를 자동 검증한 것은 아니다.
- 적용 위험: 증거 파일 보존, 앱 정리 전후 상태 구분, 삭제된 명령의 현재 안내와 과거 이력 혼동을 검토했다. 기존 `runs/` 원본은 변경 목록에 없으며 실제 파일 내용은 재검증하지 않았다.

## Critical

없음.

## Major

없음.

## Minor

### Minor-1: TASK-005의 다음 행동이 삭제된 명령을 현행 과제로 제시함

- 위치: [TASK-005](../tasks/TASK-005.md) 26행·53~61행의 다음 행동과 미완료 Acceptance Criteria; 비교 근거 [STATUS](../STATUS.md) 50행·83행.
- 확인 사실: TASK-005는 `observe.sh`의 mode별 실제 호출을 “다음 행동”으로 적고, 삭제된 명령 호출 및 기존 도구 직접 호출 보존을 미완료 기준으로 남긴다. STATUS는 그 형식이 후속 TASK-006의 단일 `monitor.sh` 명령으로 대체됐다고 기록한다.
- 발생 조건·영향: TASK-005만 따라 현재 작업을 재개하면 존재하지 않는 명령을 실행하려 하거나 이미 대체된 검증을 남은 필수 작업으로 오해할 수 있다. 이는 문서의 현재 안내와 과거 실행 계획 구분 문제이며, 실제 source 회귀는 확인되지 않았다.
- 최소 수정 방향: 당시 계획과 기준은 보존하면서, 해당 다음 행동·미완료 기준이 후속 TASK-006으로 대체되어 현재 실행 대상이 아님을 TASK-005에 짧게 표시한다.

## Good

- Good-1: [monitor.sh](../../../monitor.sh)의 이번 diff는 설정·PID 헤더와 정리 전 요약의 문구·반복 표본 발췌만 바꾼다(250행, 330~346행). 기존 2인자 `sample_csv` 분기(7~70행)와 3/4인자 수집·정리 흐름(259~328행, 349~363행)은 변경하지 않았다. 정리 전 앱 상태·수집 상태·로그 신호와 정리 후 도구 결과는 남으며, 제거한 반복 표본은 `monitor.csv`, `cpu-samples.csv`, `thread-observation.txt`에 기록하는 흐름이 유지된다.
- Good-2: [README](../../../README.md) 59~73행·112~139행은 현재 `monitor.sh` 설정값 명령과 원본 증거 파일, 메모리·교착 비교의 두 번 실행을 안내한다. 기존 PID/CSV 단독 관제 명령(89~106행)도 [monitor.sh](../../../monitor.sh) 63~70행의 2인자 분기와 일치한다. 삭제된 스크립트로 향하는 Markdown 링크는 정적 검색에서 발견되지 않았다.
- Good-3: [README](../../../README.md) 69행·[MISSION](../MISSION.md) §2~4를 대조하면 RSS, OS CPU 구간 표본, 스레드·로그 신호의 원본 수집과 정리 전후 상태 구분이 유지된다. [STATUS](../STATUS.md) 11행·15행은 CPU의 OS 급상승·Watchdog 종료 필수 근거가 아직 부족함을 계속 구분한다. 과거 리뷰와 학습 설명은 대체로 삭제 전 파일임을 표시해 당시 기록을 현재 구현으로 바꾸어 쓰지 않았다.

## PM Disposition

Minor-1은 DEFER. TASK-005의 문장은 당시 계획과 수용 기준을 기록한 이력이며, [STATUS](../STATUS.md)와 현재 [README](../../../README.md)가 mode별 명령이 공통 `monitor.sh`로 대체됐음을 안내한다. 이번 승인 범위에서는 과거 TASK의 사실 기록을 더 고치지 않는다. Critical/Major가 없어 추가 source 수정은 없다. 새 요약과 정리의 실제 동작은 사용자 실행으로 확인한다.
