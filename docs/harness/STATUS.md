# Project Status

## Current Phase

TASK-001 완료. TASK-002 메모리 설정 전후 비교·보고서 Step 승인 및 TASK 작성 완료. Implementer의 구체적 작성 계획 제시 대기.

## Completed

- 미션 원문 보존 및 요구사항 정리.
- REQ-001 사전 준비 및 부트 성공 확인.
- CSV 수집·column 조회·EXITED, 앱 로그와 시간 대조 확인.
- 기존 CSV 해시 보존, 파일 생성 실패 반환값 1 확인.
- MEMORY_LIMIT=49 실패 안내 및 변수 유지 확인.
- 관제 Ctrl+C 이후 앱 PID 12741 생존(SN, 00:11) 확인.
- REQUIRED 독립 리뷰 완료, Minor-1 반영 및 검증 완료. 추가 리뷰 SKIP.

## In Progress

[TASK-002](tasks/TASK-002.md)의 수동 비교 실험 안내·OOM 보고서·학습 보완을 준비한다. 구현 계획은 아직 미승인이다. TASK-001 학습 자료는 작성 완료이며 사용자 이해 완료는 아직 확인하지 않았다.

## Next

1. GPT-6 Sol / Medium Implementer 세션에서 TASK-002의 수정 파일·방향·영향을 제시하고 사용자 계획 승인을 받는다.
2. 승인 후 실험 안내·보고서 초안·학습 절 작성 → 사용자 최소 2회 비교 실행 → 실제 증거 반영 → PM Review Decision 및 완료 판단.

## Open Issues

- MEMORY_LIMIT 변경 전후 비교와 장애 보고서는 아직 미완료.
- CPU·Deadlock 본 실험 및 보너스 채택·제출 형식은 미정.
- 수집 중 디스크 부족 등 모든 쓰기 오류를 실행 검증한 것은 아니다. 파일 생성 실패와 기존 파일 보존은 확인했다.

## Recent Decisions

- OrbStack Linux 머신, Docker 미사용. 사용자 실행·AI 정적 검토.
- CSV 원본 저장 및 column 화면 조회. runs/ 원본은 Git 제외이므로 제출 증거는 후속 보고서에 별도 반영한다.
- TASK-002는 기존 스크립트를 재사용하며 수동 실험·보고서·학습 문서가 중심이다. 스크립트 기능 변경은 별도 계획이 필요하다.

## Current Task

[TASK-002](tasks/TASK-002.md) — Step 승인·인계 준비 완료, 구현 계획 미승인. Review 예상: RECOMMENDED(증거·원인 해석 검토), 실제 Decision은 구현 인계 후 판정한다.

이전 [TASK-001](tasks/TASK-001.md)은 완료이며 REQUIRED 독립 [리뷰](reviews/REVIEW-TASK-001.md)·Minor-1 처리 완료, 추가 리뷰 SKIP 상태를 유지한다. TASK-002 착수 전 작업 트리는 clean이고 HEAD는 `48438ce11b3e8c311b142d670515a50ac1f55e1a`였다. 이번 세션에서 Git 쓰기 작업은 하지 않았다.

## Harness Update

사용자가 제공한 갱신 템플릿의 공통 지침·학습 템플릿을 반영했다. 미션 원문·요구사항·진행 이력·실제 TASK·리뷰는 초기화하지 않았다. 앞으로 구현·수정 시 단일 [study-note.md](../study-note.md)의 해당 TASK 절을 갱신한다.
