# Review: TASK-006 승인된 리뷰 수정

- 대상: [TASK-006](../tasks/TASK-006.md), [기존 리뷰](REVIEW-TASK-006.md)의 Major-1·Major-2·Minor-1, [MISSION](../MISSION.md) §2·§4, [REQUIREMENTS](../REQUIREMENTS.md) REQ-002~004.
- 기준점과 범위: 2026-10-27 현재 미커밋 작업 트리의 [monitor.sh](../../../monitor.sh)와 [README](../../../README.md) 수정본을 기존 리뷰 지적 및 `HEAD:monitor.sh`의 2인자 수집 경로와 정적으로 대조했습니다. 자동 정리 경계 확인에 사용자 미추적 [kill-agent-leak.sh](../../../kill-agent-leak.sh)를 읽었습니다. 작업 트리의 다른 수정·미추적 파일은 이번 수정 소유로 간주하지 않았습니다.
- 독립성·한계: 구현 대화를 상속하지 않은 Reviewer의 정적 검토입니다. PM 지정 모델은 GPT-6 Sol / Medium이며 실제 실행 모델 메타데이터는 별도로 검증하지 않았습니다. 앱·스크립트 실행과 테스트를 하지 않았으므로 CPU 급상승·Watchdog 종료 증거 확보, 로그 권한 오류 재현, 신호 전달 및 포트 해제 성공은 미확인입니다.
- 안전성: 기존 CSV 파일 보호, 로그 읽기 실패 표시, PID 재사용 표시와 자동 신호 대상 고정을 확인했습니다. 제공 바이너리 내부와 C/C++ 메모리 안전성은 검토 범위 밖입니다. 프로세스 종료와 조회 사이의 실제 경합은 정적 검토만으로 제거 여부를 검증할 수 없습니다.

## Critical

없음.

## Major

없음.

## Minor

없음.

## Good

- Good-1 — 기존 Major-1 대응: [monitor.sh](../../../monitor.sh)의 `save_top_interval` 199~214행은 `top` 두 번째 프레임의 PID·CPU를 읽은 뒤 시작 식별값이 같으면 `confirmed`로, 사후 조회에서 PID가 사라지거나 종료 상태이면 `unconfirmed_after_exit`로 기록합니다. 시작값이 다른 살아 있는 PID의 행은 거부합니다. 앱의 부모 PID는 실행 때 확인한 `launcher_pid`를 `ppid_at_launch`로 기록하여 표본 뒤 `ps` 부모 조회와 앱 종료의 경합을 없앴습니다. 251행 CSV 헤더, 330~352행 요약, [README](../../../README.md) 70행은 확인 불가 표본의 해석 한계를 표시합니다. 확인 불가 행은 보존되지만 단독으로 이번 앱의 CPU 사용을 입증하지 못합니다.
- Good-2 — 기존 Major-2 대응: [monitor.sh](../../../monitor.sh)의 `show_log_signal` 147~160행은 `grep` 일치(0), 불일치(1), 읽기 오류(그 외)를 구분합니다. 337~344행은 실제 존재하는 `agent_app.log`를 검색 대상에 포함하고 각 호출 실패를 `result=1`로 반영합니다. 따라서 선택적 로그 검색 오류를 신호 부재로 표시하거나 정상 수집 종료값으로 처리하지 않습니다. [README](../../../README.md) 70행도 읽기 실패와 부분 증거를 구분합니다.
- Good-3 — 기존 Minor-1 대응: [monitor.sh](../../../monitor.sh)의 `final_pid_state` 117~131행은 정리 뒤 PID의 시작값을 대조해 동일, 재사용, 식별 불가를 별도 문구로 표시하고, 366행에서 launcher와 앱 모두에 적용합니다. [kill-agent-leak.sh](../../../kill-agent-leak.sh)의 `identity` 18~37행 및 자동 정리 87~97·103~146행은 전달받은 PID·시작값·현재 UID만 확인해 신호 대상으로 사용합니다. 상태 표시 수정이 자동 정리 대상을 넓히지 않습니다.
- Good-4 — 호환성: [monitor.sh](../../../monitor.sh)의 `sample_csv` 7~61행과 2인자 분기 63~70행은 `HEAD:monitor.sh`의 CSV 헤더·행 형식·기존 파일 덮어쓰기 방지(`set -C`)·앱 유지 흐름을 보존합니다. [README](../../../README.md) 107~109행은 2인자 호출이 추가 파일이나 자동 정리를 하지 않는다고 구분합니다. 신규 설정값 경로의 정리는 [monitor.sh](../../../monitor.sh) 361~366행에서 관측 당시 상태 기록 뒤에만 호출됩니다.

## PM Disposition

- 새 Critical/Major/Minor finding 없음. 기존 [REVIEW-TASK-006](REVIEW-TASK-006.md)의 Major-1·Major-2·Minor-1은 승인된 두 파일 수정본에서 정적으로 해결된 것으로 대조했다.
- 추가 리뷰 결정: SKIP — 이번 승인 수정의 REQUIRED 독립 재검토가 완료됐고 새 finding이 없다. 다음 단계는 사용자 실제 실행·증거 확인이다. 앱 동작·포트 해제·CPU 미션 충족은 이 정적 리뷰로 완료 처리하지 않는다.

