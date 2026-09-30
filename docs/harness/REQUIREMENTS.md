# Requirements

기준: [MISSION.md](MISSION.md). 원문과 해석이 충돌하면 원문을 우선합니다. 실행 확인 범위는 [WORKLOG](WORKLOG.md)에 기록하며 장애별 비교 실험 완료와 구분합니다.

## Required

| 상태 | ID | 원문 위치 | 요구사항 및 완료 기준 |
| --- | --- | --- | --- |
| 완료 | REQ-001 | §4 사전 준비 | 일반 사용자로 실행하고 환경변수·디렉터리·시험용 키 파일·포트 조건을 모두 충족하여 부트 성공을 사용자 확인한다. |
| 사용자 검증 완료·리뷰 대기 | REQ-002 | §2, §4 메모리 | monitor.sh로 물리 메모리 증가를 관측하고 종료 직전/직후 로그에서 MemoryGuard 임계치 초과와 자체 종료 근거를 식별한다. MEMORY_LIMIT 변경 전후 최소 2회 실행하여 생존 시간 증가와 수치를 비교한다. |
| 미완료 | REQ-003 | §2, §4 CPU | 대상 프로세스의 CPU 급상승을 top/ps/관제로 확보하고 Watchdog 종료 로그로 보호 조치를 설명한다. CPU_MAX_OCCUPY 변경 전후 종료 여부 또는 생존 시간 변화를 비교한다. |
| 미완료 | REQ-004 | §2, §4 교착상태 | PID 존재, CPU/MEM 변화 정체(top -H 또는 ps -L), 마지막 WAITING/BLOCKED 로그를 확보한다. 스레드 간 자원 대기를 근거로 교착상태를 추론하고 MULTI_THREAD_ENABLE 변경 전후 재현/회피를 비교한다. |
| 미완료 | REQ-005 | §2 | GitHub Issue 형태 보고서 3건을 작성한다. 각 보고서는 Description / Evidence & Logs / Root Cause Analysis / Workaround & Verification 구조로 현상·조건·재현 경로·객관적 증거·원인·조치·Before & After를 포함한다. PDF 또는 GitHub Repository 링크로 제출한다. |
| 미완료 | REQ-006 | §3 | 사용자가 메모리 구조와 누수 영향, 프로세스 CPU 과점유에 따른 지연, 교착상태 개념과 진단, 증거 기반 육하원칙 보고를 스스로 설명할 수 있는지 확인한다. |

## Optional

- OPT-001: 근본적 해결을 위한 추가 제안(§2). 채택 미정. 필수 조치·검증과 구분한다.
- 교착상태가 생소한 경우 식사하는 철학자들 문제와 교착상태 4대 조건 학습 권장(§4). 별도 필수 제출물로 확대하지 않는다.

## Bonus

- BONUS-001: 스케줄링 알고리즘 추론(§5, 선택). 채택 미정. 로그 타임스탬프의 실행 순서·교체 주기를 분석하여 Round-Robin / FCFS / Priority 중 추론하고 근거·장단점·적합한 서비스 아키텍처를 정리한다.

## Constraints

- §4: root가 아닌 일반 사용자, AGENT_HOME 필수, AGENT_PORT=15034 고정.
- §4: AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files 디렉터리 존재, AGENT_KEY_PATH=$AGENT_HOME/api_keys 경로 존재, AGENT_LOG_DIR 존재 및 쓰기 권한.
- §4: MEMORY_LIMIT 정수 50~512 MB, CPU_MAX_OCCUPY 정수 10~100%, MULTI_THREAD_ENABLE true/false(1/0, yes/no 허용).
- §4: $AGENT_HOME/api_keys/secret.key와 원문 지정 공개 시험용 문자열 필요. 실제 credential은 기록하지 않는다.
- §4: 0.0.0.0:15034 바인딩 가능.
- §6: 제공된 Python 기반 바이너리를 실행할 수 있는 Linux. 로컬 또는 격리 환경 권장, 공유 네트워크 방화벽 설정 유의. 디컴파일·리버스 엔지니어링 금지.
- §7: monitor.sh, ps, top, htop, pstree, kill 등 Linux 표준 명령어 및 라이브러리 사용.

## Notes

- 제공 파일: [x86 바이너리](../../agent-app-leak/agent-leak-app-x86), [arm64 바이너리](../../agent-app-leak/agent-leak-app-arm64). 사용자가 x86 바이너리 실행을 검증했다. AI는 실행 및 내부 분석을 하지 않았다.
- 2026-09-29 사용자 확인: monitor.sh 별도 제공본 없음. [TASK-001](tasks/TASK-001.md)에서 최소 스크립트를 작성한다. 실행 환경은 macOS 호스트의 OrbStack Linux 머신이며 Docker를 사용하지 않는다.
- OOM 명칭과 별개로 필수 분석 대상은 MemoryGuard에 의한 자체 종료다. OS OOM Killer 작동이나 종료 신호는 실제 증거 없이 단정하지 않는다.
- §8의 수치·시간·원인 설명은 참고 예시이며 실제 실행 증거로 사용하지 않는다.
- 실제 GitHub Issue 게시를 필수로 확대하지 않는다.
- 구현만 끝나고 사용자 확인 전이면 완료 처리하지 않는다. 선택·보너스 미채택과 필수 미완료를 구분한다.

- 2026-09-30 TASK-002 PM 확인: 128/256MB에서 MemoryGuard 자체 종료와 관측 시간 17초→33초를 원본과 대조했다. [OOM 보고서](../reports/oom.md) 작성 확인. REQ-005의 CPU·Deadlock 보고서와 전체 제출은 미완료이며, TASK-002 독립 리뷰·학습 최종 정리는 남아 있다.
