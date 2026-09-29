# Project Status

## Current Phase

TASK-001 완료. 하네스 학습 규칙 갱신과 TASK-001 학습 자료 작성 완료. 다음 Step 전 학습 진행.

## Completed

- 미션 원문 보존 및 요구사항 정리.
- REQ-001 사전 준비 및 부트 성공 확인.
- CSV 수집·column 조회·EXITED, 앱 로그와 시간 대조 확인.
- 기존 CSV 해시 보존, 파일 생성 실패 반환값 1 확인.
- MEMORY_LIMIT=49 실패 안내 및 변수 유지 확인.
- 관제 Ctrl+C 이후 앱 PID 12741 생존(SN, 00:11) 확인.
- REQUIRED 독립 리뷰 완료, Minor-1 반영 및 검증 완료. 추가 리뷰 SKIP.

## In Progress

[학습 노트](../study-note.md)를 실행 순서대로 읽고 질문을 보완한다. 사용자 이해 완료는 아직 확인하지 않았다.

## Next

1. TASK-001 학습 순서: 셸·환경변수 → 실행·PID → CSV·지표·파일 보호 → 로그 연결·실패 → 연습 질문.
2. 학습 후 사용자 요청에 따라 TASK-002 메모리 설정 전후 비교와 보고서 범위를 제안한다. 아직 TASK-002는 생성하지 않았다.

## Open Issues

- MEMORY_LIMIT 변경 전후 비교와 장애 보고서는 아직 미완료.
- CPU·Deadlock 본 실험 및 보너스 채택·제출 형식은 미정.
- 수집 중 디스크 부족 등 모든 쓰기 오류를 실행 검증한 것은 아니다. 파일 생성 실패와 기존 파일 보존은 확인했다.

## Recent Decisions

- OrbStack Linux 머신, Docker 미사용. 사용자 실행·AI 정적 검토.
- CSV 원본 저장 및 column 화면 조회. runs/ 원본은 Git 제외이므로 제출 증거는 후속 보고서에 별도 반영한다.

## Current Task

[TASK-001](tasks/TASK-001.md) — 완료. 별도 Implementer 완료 보고가 없다는 사용자 설명을 반영하여 기존 검토·실행 증거와 요청된 학습 문서로 설명 누락을 보완했다.
Review Decision: REQUIRED 실시 완료([리뷰](reviews/REVIEW-TASK-001.md)), Minor-1 처리 완료. 추가 리뷰 SKIP(안내 출력·문서 보완에 한정).
커밋은 실행·관제 스크립트와 관련 문서를 묶어 권장하며 실제 Git 쓰기 작업은 하지 않았다.

## Harness Update

사용자가 제공한 갱신 템플릿의 공통 지침·학습 템플릿을 반영했다. 미션 원문·요구사항·진행 이력·실제 TASK·리뷰는 초기화하지 않았다. 앞으로 구현·수정 시 단일 [study-note.md](../study-note.md)의 해당 TASK 절을 갱신한다.
