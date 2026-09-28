# Project Status

## Current Phase

미션 시작 분석 완료. Roadmap·README 골격 및 첫 Step 승인 대기.

## Completed

- 첨부 원문을 [MISSION.md](MISSION.md)에 보존했다.
- [REQUIREMENTS.md](REQUIREMENTS.md)에 필수·선택·보너스·제약을 정리했다.
- 프로젝트 기능 및 사용자 실행 검증 완료 항목은 없다.

## In Progress

실행 환경·monitor.sh 제공 여부 확인 및 첫 단계 범위 논의.

## Next

1. README 골격과 TASK-001 범위 승인.
2. 승인 후 TASK 작성 및 Implementer 수동 인계. source 수정 계획 승인은 별도다.

Roadmap 제안: 실행·관제 준비 → 메모리 분석/보고서 → CPU 분석/보고서 → Deadlock 분석/보고서 → 제출 정리. 스케줄링 보너스는 선택 후 진행한다.

## Open Issues

- monitor.sh 별도 제공 여부 미확인(저장소에 없음).
- 실제 실행할 Linux 환경·CPU 아키텍처·도구·포트 상태는 사용자 확인 전.
- README 제안: 소개 / 실제 프로젝트 구조 / 실행 환경·방법 / 관제 및 증거 수집 / 장애 보고서 링크·비교표. 초기에는 검증 대기 표시. 별도 구조도 없이 실제 증거 확보 후 필요한 그래프 반영. 승인 전 미생성.
- 보너스 채택과 제출 형식(PDF 또는 Repository 링크) 미정.

## Recent Decisions

- 바이너리 수정·역공학 없이 실행 로그와 관제 자료로 분석한다.
- 실행·테스트는 사용자가 수행하며 예시를 실제 결과로 기록하지 않는다.
- source 및 실행 설정 변경은 Implementer가 계획을 제시하고 명시적 승인 후 수행한다.

## Current Task

없음. TASK-001(실행 환경 및 관제 준비) 제안 상태이며 승인 후 작성한다.
Review 예상: REQUIRED — 관제 로그 저장과 실행 설정 검토 필요. 실제 구현 결과로 재평가한다.

기존 AGENTS.md, docs/, agent-app-leak/는 시작 시 미추적 상태였다. Git 쓰기 작업은 하지 않았다. 초기 문서 구성 확정 후 커밋 묶음을 판단한다.
