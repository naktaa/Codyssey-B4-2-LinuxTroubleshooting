# Review: TASK-006

- 대상: [TASK-006](../tasks/TASK-006.md), [MISSION](../MISSION.md) §2·§4, [REQUIREMENTS](../REQUIREMENTS.md) REQ-002~004.
- 기준점: 2026-10-27 현재 작업 트리. `git diff`와 파일 전체를 함께 확인했습니다. [monitor.sh](../../../monitor.sh), `run-cpu-observation.sh` (삭제 전), `run-deadlock-observation.sh` (삭제 전), [README](../../../README.md)는 추적 파일이고, `observe.sh` (삭제 전), `observe-memory.sh` (삭제 전), [kill-agent-leak.sh](../../../kill-agent-leak.sh)는 미추적 파일입니다. 다른 사용자 변경은 TASK-006 소유로 간주하지 않았습니다.
- 관련 읽기 전용 확인: [prepare-env.sh](../../../prepare-env.sh), `run-memory-comparison.sh` (삭제 전), `memory-test.sh` (삭제 전), 기존 `HEAD:monitor.sh`.
- 독립성·한계: 구현 대화를 상속하지 않은 Reviewer의 정적 검토입니다. PM 지정 모델은 GPT-6 Sol / Medium이며 실제 실행 모델 메타데이터는 이 문서에서 별도로 검증하지 않았습니다. 앱 실행·테스트는 하지 않았으므로 CPU 장애 근거 확보, 종료 신호 결과, 포트 해제 성공을 추정하지 않습니다.
- 안전성: 기존 증거 덮어쓰기 방지와 PID 신호 대상을 검토했습니다. 바이너리 내부·C/C++ 메모리 안전성은 이번 셸 변경 범위에 해당하지 않습니다. 실제 파일시스템 권한·프로세스 경합은 실행 미검증입니다.

## Critical

없음.

## Major

### Major-1 — 앱의 정상 종료 경합에서 유효한 CPU 표본을 수집 실패로 처리

[monitor.sh](../../../monitor.sh)의 `save_top_interval` 180~182행은 `top` 두 번째 프레임에서 앱 PID와 CPU 값을 읽은 뒤 현재 `ps -p PID -o ppid=` 조회를 필수로 요구합니다. 앱이 `top` 표본 직후 MemoryGuard 또는 Watchdog으로 종료하면 이 조회가 실패하고 253~255행에서 전체 관측 결과를 실패로 표시합니다. 빠른 자체 종료는 미션의 핵심 관측 조건이므로 실제로 유효한 구간 CPU 값과 보호 종료 로그가 남아도 실행이 불완전하다고 처리될 수 있습니다. 최소 수정 방향: 실행 때 이미 확인한 앱의 부모 PID를 사용하거나, 종료 경합에서는 PPID를 미확인으로 기록해 CPU 표본을 보존하고 종료 상태·로그로 원인을 구분하세요.

### Major-2 — 선택적 앱 로그의 읽기 실패가 신호 부재로 표시됨

[monitor.sh](../../../monitor.sh)의 `show_log_signal` 130~137행은 `grep` 실패를 `|| true`로 덮고 빈 결과를 모두 `no matching line found in readable logs`로 출력합니다. 301~308행에서 존재하는 `agent_app.log`가 읽기 오류를 내거나 조회 중 사라져도, `app.log` 부트 마커와 다른 표본이 정상이라면 319~336행의 최종 종료값이 0일 수 있습니다. 이 경우 관측 실패가 로그 신호 부재로 바뀌어 보호 종료 해석의 근거를 잘못 안내합니다. 최소 수정 방향: 존재하는 로그의 검색 실패와 일치 행 없음은 구분하고, 읽기 실패를 요약과 종료 상태에 반영하세요.

## Minor

### Minor-1 — 정리 뒤 PID 상태가 시작 식별값 없이 표시됨

[monitor.sh](../../../monitor.sh)의 `pid_state` 105~114행은 PID만 조회하고, 327행의 최종 상태 출력도 시작 식별값을 재검증하지 않습니다. 정리 중 PID가 재사용되면 다른 프로세스의 상태가 이번 실행의 최종 launcher/app 상태처럼 표시될 수 있습니다. 종료 신호 자체는 [kill-agent-leak.sh](../../../kill-agent-leak.sh)의 `identity` 18~37행에서 시작값·UID를 확인하므로 이 지적은 요약의 정확성에 한정됩니다. 최소 수정 방향: 최종 상태 출력에서 시작값 불일치를 별도 상태로 표시하세요.

## Good

- Good-1: [monitor.sh](../../../monitor.sh)의 `sample_csv` 7~69행은 기존 2인자 CSV 헤더·수집 형식·앱 유지·noclobber를 유지하고, 새 설정값 경로와 분리합니다. `run-memory-comparison.sh` (삭제 전)와 `memory-test.sh` (삭제 전)의 기존 호출 형식도 정적으로 대조했습니다.
- Good-2: [monitor.sh](../../../monitor.sh)의 `save_top_interval` 140~187행은 첫 `top` 프레임을 제외하고 PID를 선택하며, 116~127행은 앱 PID만 `ps -L`로 기록합니다. [README](../../../README.md)는 수명 평균 CPU와 구간 CPU, 내부 Load와 OS `%CPU`의 차이를 설명하고 새 경로를 미검증으로 표시합니다.
- Good-3: [monitor.sh](../../../monitor.sh) 294~327행은 정리 전 상태와 로그 신호를 먼저 남깁니다. [kill-agent-leak.sh](../../../kill-agent-leak.sh) 87~163행은 자동 대상 목록을 PID·시작값으로 고정하고 UID를 확인하며, `ss` 실패를 성공으로 취급하지 않고 포트의 다른 점유자를 신호 대상으로 추가하지 않습니다. 무인자 경로 39~86행은 정확한 실행 파일 경로와 대화형 확인을 요구합니다.

## PM Disposition

- **Major-1 — ACCEPT (이번 수정):** `top` 표본 직후의 자연·보호 종료는 미션의 핵심 경로다. 표본 후 `ps` 조회 실패만으로 유효한 CPU 표본 전체를 실패 처리하는 것은 부적절하다. 재사용 PID를 이번 앱으로 오인하지 않는 범위에서 종료 경합을 허용하는 수정 계획을 사용자에게 제시한다.
- **Major-2 — ACCEPT (이번 수정):** 실제 로그 읽기 오류와 해당 문구 부재를 구분해야 한다. 로그 읽기 실패는 부분 증거·비정상 종료로 표시하는 계획을 사용자에게 제시한다.
- **Minor-1 — ACCEPT (이번 수정):** 정리 뒤 PID 표시는 이번 실행 여부를 함께 보여야 한다. 기존 시작 식별값을 사용해 재사용 PID를 구분하는 계획을 사용자에게 제시한다.
- 위 disposition은 수정 승인이 아니다. Implementer의 읽기 전용 수정 계획을 회수한 뒤 사용자 승인 전에는 source를 변경하지 않는다. 앱 실행·테스트는 사용자 담당이다.
