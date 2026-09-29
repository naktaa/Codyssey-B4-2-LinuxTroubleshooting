# Review: TASK-001

- 기준점: `047aeb2bdc77e40fc7f8923ebfce8cc6813634a1`
- 검토 범위: [TASK-001](../tasks/TASK-001.md)의 승인 범위와 [MISSION](../MISSION.md)·[REQUIREMENTS](../REQUIREMENTS.md)을 기준으로 [monitor.sh](../../../monitor.sh), [prepare-env.sh](../../../prepare-env.sh), [.gitignore](../../../.gitignore), [README.md](../../../README.md)를 정적 검토했다.
- 네 검토 파일은 모두 미추적 신규 파일이다. 지정 기준점의 `git diff`가 비어 있어 각 파일 본문을 직접 확인했다. 그 밖의 수정·미추적 파일은 이번 리뷰 범위에서 제외했다.
- 실행·테스트와 바이너리 내부 확인은 수행하지 않았다. 부트 성공, 실제 관제 수치, 포트 바인딩, 파일 시스템 오류 시 동작은 사용자 검증이 필요하다.

## Critical

없음.

## Major

없음.

## Minor

### Minor-1: 실패한 재준비 뒤 이전 실행의 PID·로그 경로가 현재 셸에 남음

- 위치: [prepare-env.sh](../../../prepare-env.sh)의 `codyssey_prepare_env` 22~27행, 60~74행, 124~128행; [README.md](../../../README.md) 36~43행.
- 확인된 사실: 스크립트는 `source`로 실행되어 `run_dir`, `app_pid`, `launcher_pid`를 호출 셸에 남긴다. 이 값들은 새 실행의 로그와 바이너리를 준비한 뒤에만 갱신되며, 앞선 검증에서 `return 1`하면 이전 값이 유지된다. README의 2단계 명령은 앞 단계의 성공 여부를 검사하지 않고 현재 셸의 `run_dir`을 사용한다.
- 발생 조건·영향: 첫 실행 후 같은 셸에서 다시 `source`했는데 기존 PID 감지, 잘못된 설정값, 포트 점유 등으로 실패한 뒤 2단계 명령을 수동 실행하면 이전 실행의 `app.log`를 새 시도의 로그로 오인할 수 있다. 오류 자체는 반환하므로 자동으로 성공 처리되는 문제는 아니다.
- 최소 수정 방향: 실패 후 남는 PID·경로의 의미를 출력과 README에서 명확히 구분하거나, 재시도 실패 시 현재 실행으로 해석될 변수를 무효화한다. 이전 실행의 증거 파일은 보존한다.

## Good

- [monitor.sh](../../../monitor.sh)의 `set -C`와 새 로그 파일 열기(29~34행)는 같은 경로의 기존 관제 증거를 덮어쓰지 않도록 한다. 종료 시 행을 남기고, `ps` 파싱·쓰기 오류를 성공으로 처리하지 않는다(47~75행).
- [prepare-env.sh](../../../prepare-env.sh)는 기존 시험용 키를 덮어쓰지 않고 내용이 다르면 중단하며(92~102행), 실행별 디렉터리와 앱 로그를 만든 뒤 바이너리를 시작한다(104~126행). [.gitignore](../../../.gitignore)는 `runs/`만 제외하고, [README.md](../../../README.md)는 그 증거가 저장소 복제 시 전달되지 않음을 알린다.

## PM Disposition

- Minor-1: **ACCEPT (이번 수정)**. prepare-env.sh의 조기 실패 경로에서 이전 셸 변수가 유지되고 README의 개별 조회 명령이 이를 사용하는 것을 실제 코드와 대조했다. 미션의 실행별 증거 식별에 혼동을 줄 수 있어 반영한다.
- 권장 최소 수정: prepare-env.sh의 최종 실패 분기에서 준비 실패와 셸의 PID·경로가 성공한 새 실행을 보장하지 않음을 알린다. 실패가 앱 시작 후에도 발생할 수 있으므로 앱이 실행되지 않았다고 단정하지 않는다. README에 실패 시 다음 관제·조회 단계로 진행하지 말고 오류 및 해당 실행 상태를 확인하도록 명시한다.
- 기존 PID·경로는 중복 실행 방지와 실패 후 진단에 필요하므로 일괄 초기화하지 않는다. 기존 증거 파일과 앱 생명주기는 변경하지 않는다.
- 수정 범위: prepare-env.sh의 실패 안내 출력 및 README의 실패 후 사용 안내. 사용자가 “그럼 보완하는걸로 해보자”로 위 구체적 계획을 승인했다. Implementer 반영 대기. 승인 내역은 [TASK-001](../tasks/TASK-001.md)에 기록했다.
- DEFER / REJECT: 없음. 독립 리뷰는 완료되었으나 지적 사항 처리 및 사용자 검증은 남아 있다.

### Minor-1 수정 확인 및 사용자 검증

- 정적 확인: prepare-env.sh 최종 실패 분기에 stderr 안내 추가, README에 실패 후 다음 단계 중단·이전 변수 오인 방지·앱 시작 후 실패 가능성 설명 반영.
- 사용자 실행: 서브셸에서 app_pid=99999999, launcher_pid=99999998, run_dir=/tmp/previous-run, MEMORY_LIMIT=49를 설정하고 source 실행.
- 실제 결과: MEMORY_LIMIT 범위 오류와 추가 실패 안내 출력, 반환값 1, app_pid=99999999 및 run_dir=/tmp/previous-run 유지. Minor-1의 해당 확인 시나리오 통과. 이 결과를 정상 실행·모든 실패 경로의 검증으로 확대하지 않는다.
- Review Decision: 추가 리뷰 SKIP. 기존 REQUIRED 독립 리뷰는 완료되어 있으며 이번 수정은 실패 안내와 문서에 한정된다. 추천 Reviewer/Reasoning: 해당 없음.
- 다음: 최신 CSV 관제·column 조회 및 로그 보존·저장 실패·관제 중단 확인, Implementer self-check·코드 설명 인계 확인 후 TASK 완료 판단.
