# Review: TASK-002

- 대상: [TASK-002](../tasks/TASK-002.md), [MISSION](../MISSION.md)의 OOM 요구사항, [REQUIREMENTS](../REQUIREMENTS.md)의 REQ-002·REQ-005.
- 변경 기준점: `48438ce11b3e8c311b142d670515a50ac1f55e1a`. 현재 작업 트리의 [run-memory-comparison.sh](../../../run-memory-comparison.sh), [OOM 보고서](../../reports/oom.md), [README.md](../../../README.md), [TASK-002.md](../tasks/TASK-002.md)를 검토했다. 앞의 두 파일은 미추적 상태로 직접 읽었고, 뒤의 두 파일은 기준점 대비 변경을 확인했다. 공통 하네스 변경은 범위에서 제외했다.
- 참조: [prepare-env.sh](../../../prepare-env.sh), [monitor.sh](../../../monitor.sh), 로컬 `runs/`의 비교 출력과 네 실행의 원본 CSV·앱 로그. `runs/`는 Git 제외 자료다.
- 방법·한계: 정적 코드·문서 검토와 이미 존재하는 사용자 실행 기록 대조만 수행했다. 스크립트 실행·테스트·실패 주입은 하지 않았으므로 아래 실패 경로의 실제 발생 여부는 미확인이다. 제공 바이너리 내부 동작과 OS OOM Killer 이벤트도 확인하지 않았다.

## Critical

없음.

## Major

### Major-1 — 부트 실패 후에도 다음 실행으로 넘어갈 수 있음

- 위치: [run-memory-comparison.sh](../../../run-memory-comparison.sh) `run_case`, 60–70행·72–105행·150–154행; 참조 [prepare-env.sh](../../../prepare-env.sh) `codyssey_prepare_env`, 130–144행.
- 확인된 사실: `prepare-env.sh`의 성공은 자식 PID 식별까지만 보장하고 출력도 `Started (boot unverified)`라고 명시한다. 비교 스크립트는 관제 CSV에 RUNNING·EXITED와 RSS가 있고 `app.log`를 읽을 수 있으면 부트 성공 여부나 앱 오류 로그를 검사하지 않고 성공을 반환한다. `head`와 `tail`은 로그 내용이 실패 메시지여도 읽기에 성공한다.
- 영향·발생 조건: 자식이 관제 첫 표본 이후 부트 검사에서 실패하거나 다른 오류로 종료하면, 첫 실행을 완료한 것으로 보고 두 번째 앱을 시작하고 최종 종료 코드도 0이 될 수 있다. 실제 사용자 기록의 두 실행은 `All Boot Checks Passed!`와 `Agent READY`가 있어 이 문제가 발생한 사례는 아니다.
- 최소 수정 방향: 첫 실행을 성공으로 넘기기 전에 해당 실행의 부트 성공 표식을 확인하고, 없으면 실패를 기록한 뒤 다음 실행을 중단한다. 정상 종료 원인 판정은 원본 로그를 통해 별도로 유지한다.

### Major-2 — 비교 출력 저장 실패를 두 번째 실행 전에 감지하지 못함

- 위치: [run-memory-comparison.sh](../../../run-memory-comparison.sh) `run_comparison`, 146–155행 및 파이프라인 상태 처리 159–175행.
- 확인된 사실: `run_comparison` 전체를 한 번 `tee -a`에 연결하고, `log_status`는 두 실행이 끝난 뒤에만 읽는다. 최종 실패 코드를 1로 만드는 처리는 있으나, 첫 실행 중 `output.log` 쓰기에 실패했는지 확인하는 분기 없이 `after`를 시작한다.
- 영향·발생 조건: 첫 실행 중 비교 출력 파일의 쓰기 오류가 나고 `tee`가 화면 출력을 계속할 경우, 원본 CSV·앱 로그는 각각 남더라도 비교 출력이 누락된 상태에서 두 번째 실험이 진행된다. 이는 첫 실행의 증거 저장 실패 시 다음 실행을 중단한다는 TASK의 실패 처리 취지와 맞지 않는다. 쓰기 실패 조건은 실행으로 재현하지 않았다.
- 최소 수정 방향: 첫 실행이 끝날 때 출력 저장 상태를 확인해 실패 시 다음 실행을 중단하고 비정상 종료 코드를 남긴다. 기존 고유 경로와 원본 증거 보존 방식은 유지한다.

## Minor

### Minor-1 — README 도입부의 진행 상태가 현재 보고서와 다름

- 위치: [README.md](../../../README.md) 5행; 같은 파일 101–105행과 [OOM 보고서](../../reports/oom.md) 35–45행.
- 확인된 사실: 도입부는 장애별 비교·보고서가 “진행 전”이라고 하지만, 아래에서는 128/256MB 비교와 OOM 보고서 완료를 안내한다.
- 영향·발생 조건: README 첫 문단만 읽는 사용자는 OOM 산출물이 아직 없다고 이해할 수 있다.
- 최소 수정 방향: 도입부를 OOM 비교·보고서 완료, CPU·Deadlock 대기로 맞춘다.

## Good

- [run-memory-comparison.sh](../../../run-memory-comparison.sh) 130–144행은 고유 디렉터리와 `noclobber`로 기존 비교 로그를 보호하고, [prepare-env.sh](../../../prepare-env.sh) 104–113행 및 [monitor.sh](../../../monitor.sh) 29–39행은 실행별 앱 로그·CSV를 분리한다. 실패 시 원본을 자동 삭제하거나 프로세스를 강제 종료하는 경로는 검토 범위에서 확인되지 않았다.
- [OOM 보고서](../../reports/oom.md) 35–82행의 128/256MB 표와 발췌는 로컬 원본의 PID 8661·8790, 첫 RUNNING→EXITED 17초·33초, 최고 표본 RSS 146,520·274,628 KiB 및 MemoryGuard 로그와 일치한다. [비교 출력](../../../runs/comparison-8mGJ3y/output.log)에도 두 실행의 원본 경로와 최종 코드 0이 남아 있다. Git 제외 자료를 대신할 핵심 행을 보고서에 실었다.
- [OOM 보고서](../../reports/oom.md) 99–181행은 앞선 256/512MB 실행에서 After가 CpuWorker 경로로 바뀐 점을 분리해 설명한다. RSS·앱 Heap·시스템 `%MEM`을 구분하고, 앱 자체 종료를 OS OOM Killer 작동으로 단정하지 않는다.

## PM Disposition

2026-09-30 PM: 현재 코드·TASK·README와 대조했다. REQUIRED 독립 리뷰 실시 완료이며 지적 처리와 검증 전까지 TASK는 미완료다.

| Finding | 판정 | 근거·이번 수정 경계 |
| --- | --- | --- |
| Major-1 | ACCEPT | PID 식별·CSV 수집 성공만으로 부트 성공을 보장하지 못한다. 비교 스크립트에서 각 실행의 앱 로그에 부트 성공 표식이 있는지 확인하고, 없으면 비정상 반환 및 다음 실행 중단. MemoryGuard 등 부트 이후 의도된 장애를 일괄 실행 실패로 분류하지 않는다. |
| Major-2 | ACCEPT | 현재 tee 상태 확인은 두 실행 뒤라 첫 실행의 비교 로그 저장 실패가 after 시작을 막지 못한다. before 출력 저장 완료·성공을 확인한 뒤에만 after를 시작하도록 변경한다. 저장 불가 시 최종 코드를 파일에 반드시 남길 수는 없으므로 stderr 안내와 비정상 종료를 보장한다. |
| Minor-1 | ACCEPT | README 도입부를 OOM 비교·보고서 작성 및 사용자 결과 확인, TASK 리뷰 지적 처리 중, CPU·Deadlock 대기로 동기화한다. TASK 전체 완료로 쓰지 않는다. |

DEFER/REJECT 없음. 2026-09-30 사용자의 “오케이 보완하자 그럼”으로 세 항목의 위 보완 계획을 승인받았다. 동일 계획은 재승인 없이 Implementer가 반영한다. 수정 대상은 [비교 스크립트](../../../run-memory-comparison.sh)와 [README](../../../README.md)이며 기존 준비·관제 도구, 원본 증거와 보고서 수치는 유지한다. 학습 노트는 TASK 마감 시 정리한다.

다음: Implementer 승인 계획 반영 → 정적 self-check → PM 추가 리뷰 판단과 사용자 실패 경로 검증. 실제 실패 재현은 아직 미확인이다.


### 보완 반영 PM 확인

2026-09-30 사용자 구현 완료 인계 후 정적으로 확인했다. Major-1은 비교 스크립트 run_case 108~113행의 두 부트 표식 검사로, Major-2는 run_comparison 171~181행의 before 파이프라인 완료 직후 PIPESTATUS 검사 및 실패 반환으로 반영됐다. Minor-1은 README 도입부에 반영됐다. 세 항목 모두 구현 반영 확인이며 실패 경로 실제 실행 통과를 뜻하지 않는다.

Review Decision: 추가 독립 리뷰 SKIP. 기존 REQUIRED 리뷰는 실시 완료이며 수정은 승인된 단일 스크립트의 명시적 성공 표식 검사와 실행별 tee 상태 분리·README 문구에 한정됐다. 실패 반환부터 after 호출 전 분기까지 정적으로 대조했다. 추가 Reviewer/Reasoning은 해당 없음. 다음은 현재 수정본의 정상 비교와 부트 표식 누락·before 로그 저장 실패 시 after 미실행·비정상 반환에 대한 사용자 확인이다.

이번 사용자 요청에 한해 PM이 [학습 노트](../../study-note.md)를 현재 코드 기준으로 정리했다. 공통 역할 정책을 변경한 것은 아니며 TASK는 사용자 검증 대기로 유지한다.
