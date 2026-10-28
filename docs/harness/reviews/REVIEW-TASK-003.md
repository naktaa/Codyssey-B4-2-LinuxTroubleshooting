# Review: TASK-003 실행 도구 인자화

- 기준: HEAD `346afbbdbf000627cf605eded8bcddb1feb841b3` 대비 작업 트리 diff. [TASK-003](../tasks/TASK-003.md)의 2026-10-13 승인된 인자화 범위만 검토했다. PM의 TASK 상태 기록 변경은 승인 근거로만 참조했다.
- 검토 파일: [prepare-env.sh](../../../prepare-env.sh), `run-memory-comparison.sh` (삭제 전), [README.md](../../../README.md). 관련 호출 문맥과 [MISSION](../MISSION.md)·[REQUIREMENTS](../REQUIREMENTS.md)를 대조했다.
- 위임 정보: PM 지정 모델 ID·reasoning은 이 Reviewer에게 전달되지 않았고, 실제 실행 모델 메타데이터도 확인하지 않았다. 구현 대화는 상속받지 않았다. 결과 위치는 이 문서다.
- 검토 방법과 한계: 코드와 diff만 읽었다. source 실행, 테스트, 실제 앱 시작, CPU 관측은 하지 않았다. 따라서 인자화의 실제 동작 성공이나 TASK-003의 CPU 급상승·Watchdog 종료·전후 비교 완료를 판정하지 않는다.

## Critical

없음.

## Major

없음.

## Minor

없음.

## Good

- [prepare-env.sh](../../../prepare-env.sh)의 `codyssey_prepare_env` 14~18행·66~85행은 인자를 0개 또는 3개로 제한하고, 3개일 때 인자를 우선하며 기존 수치·불리언 검증을 그대로 적용한다. 무인자 경로의 환경변수·기본값 선택도 유지한다.
- `run-memory-comparison.sh` (삭제 전)의 `run_case` 50~63행은 함수의 위치 인자가 무인자 `source`에 상속될 수 있는 상황을 피하도록 세 설정을 명시한다. 기존 비교의 두 메모리 값과 고정 CPU·멀티스레드 값 전달 관계가 유지된다.
- [README.md](../../../README.md) 23~39행·72~78행은 인자 순서, 허용 범위, 우선순위, 무인자 사용법을 안내하고, 메모리·CPU·멀티스레드 설정 쌍을 검증 결과가 아닌 입력 예시로 구분한다.
- 인자 검증은 [prepare-env.sh](../../../prepare-env.sh)의 디렉터리·키·로그 생성과 앱 시작 전 14~85행에서 끝난다. 변경 diff에는 기존 원본의 덮어쓰기·삭제, 바이너리·관제 도구 수정, credential 추가가 없다. 기존 고유 실행 디렉터리와 키 비교 경로는 유지된다. 파일·데이터 안전성은 정적 범위에서만 확인했으며, 이 Bash 변경에는 C/C++ 메모리 관리 검토가 적용되지 않는다.

## PM Disposition

- 수정할 finding 없음. 승인 범위 및 실제 diff와 대조했다. REQUIRED 독립 정적 리뷰 완료, 실행 검증은 사용자 대기다.
- PM 호출 기록 보완: `gpt-6-sol` / `medium`, `fork_turns="none"`으로 지정했고 도구가 수락했다. 실행 모델 메타데이터를 별도로 검증한 것은 아니다.
