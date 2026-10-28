# Project Status

## Current Phase

2026-10-28 [TASK-003](tasks/TASK-003.md) [CPU 보고서](../reports/cpu.md)에 사용자 실행의 새 512/80/false 앱 로그와 0.1초·1초 OS CPU 표본을 추가했다. 대상 프로세스의 0.1초 순간 상승은 확인했지만 앱 내부 `Current Load`와 동일한 정의, 지속 과점유·시스템 지연, Watchdog/SIGTERM 종료 주체는 확인되지 않았다. 종전 40% After의 OS CPU 수치와 새 0.1초 표본은 같은 수집법의 전후 효과로 비교하지 않는다. Review Decision: SKIP — 기존 독립 리뷰 후 제한된 증거 보강이며 원본·source 변경이 없다. 사용자 보고서 확인 대기.

2026-10-28 [TASK-003](tasks/TASK-003.md) 출력 형식 후속: 사용자 승인으로 설정값 호출 시 PID, 관측·수집·정리 상태, 결과 폴더와 최종 결과를 터미널에 간결하게 표시한다. 새 CPU CSV의 경과 시간·간격·구간 CPU·그룹 합계는 소수점 2자리 표시이며 계산은 원값이다. 정적 문법·diff 확인만 마쳤고 새 출력의 사용자 실행 확인은 대기한다. Review Decision: SKIP — 기존 REQUIRED 리뷰 이후 표시와 문서만 변경했다.

2026-10-28 [TASK-003](tasks/TASK-003.md) C 수집기 도입 당시: 사용자 요청으로 C 프로세스 CPU 시계 수집기를 `monitor.sh`에 연결했다. 설정값 실행은 C를 자동 컴파일하고 앱 PID를 검증해 100ms·약 1초 CPU CSV를 만든다. 양수 표본은 그룹별로 구분하고 마지막 행의 퍼센트 단순 합은 실제 CPU 사용률과 별도다. REQUIRED [독립 리뷰](reviews/REVIEW-TASK-003-CPU-PRECISE.md)는 Critical/Major 0, README 안내 Minor 1을 승인 범위에서 수정했다. 이후 사용자가 C 방식의 실행 로그를 제공했으며 앱 내부 상승 속도는 같은 설정에서도 달랐다. CPU 미션의 OS 급상승·Watchdog 결론은 자동 완료 처리하지 않는다.

2026-10-28 [TASK-008](tasks/TASK-008.md): 사용자 승인으로 `monitor.sh`만 현재 관측 명령으로 안내하고, 사용하지 않는 실행 스크립트 6개를 삭제했다. `observation.txt`의 반복 표본을 없애고 정리 전 앱 상태·로그 신호·정리 결과는 유지했다. README와 삭제 파일을 가리키던 문서 링크를 정리했다. REQUIRED [독립 리뷰](reviews/REVIEW-TASK-008.md)는 Critical/Major 0, 역사적 TASK-005 안내에 관한 Minor 1을 DEFER로 분류했다. 새 형식의 실제 실행 확인은 사용자 담당이며 아직 수행하지 않았다.

2026-10-28 [TASK-007](tasks/TASK-007.md) 보너스 [스케줄링 보고서](../reports/scheduling.md)와 [최종 학습 절](../study-note.md#task-007-정상-실행-로그의-스케줄링-패턴-추론)을 정리했다. 한 정상 실행의 A→B→C 기록 간격과 FCFS·SJF·SRT·RR·Priority·HRN의 구별 한계를 설명하고, FCFS형 가설의 장단점·서비스 적합성을 포함했다. 실제 OS·앱 정책이나 RR 시간 할당량을 확정하지 않는다. 사용자는 독립 리뷰를 생략했고 후속 한 문단 보완은 SKIP이다. 문서 작성은 사용자 이해 완료를 뜻하지 않는다.

2026-10-28 사용자 요청으로 [OOM 보고서](../reports/oom.md)의 Before/After를 공통 `monitor.sh`로 실행된 128MB·300MB, CPU 40%, 멀티스레드 false 두 건으로 바꿨다. 128MB는 첫 RUNNING 뒤 17초에 MemoryGuard 자체 종료, 300MB는 부트 메모리 검사 OK 뒤 Heap 300MB에서 MemoryWorker 정리·회복을 기록하고 60초 관측 끝에도 생존했다. 300MB의 실행 중 WARNING은 종료 경고와 구분하며, 관측 뒤 앱은 도구가 정리했다. 앱 작업 경로와 관측 상한이 달라 한도 상향의 단독 인과 효과는 미확인이다. 사용자 보고서 확인·RECOMMENDED 리뷰 선택 및 TASK-002 학습 절 동기화 대기.

2026-10-28 사용자 요청으로 [OOM](../reports/oom.md)·[CPU](../reports/cpu.md)·[Deadlock](../reports/deadlock.md) 보고서의 표기와 톤을 다듬었다. 처음 압축본에서 빠진 핵심 원본 행은 사용자 지적에 따라 Before/After의 앱·관제·top/ps 블록에 복원했다. RSS 요약은 정수 MB로 환산하고 설명의 실행 식별자·불필요한 시각·반복 PID를 제거했다. 교착의 PID 존재 근거는 필수라 남겼다. 보고서 사용자 확인과 RECOMMENDED 독립 리뷰 선택을 기다린다. CPU 필수 증거 미충족은 유지한다.

2026-10-28 [TASK-003](tasks/TASK-003.md) CPU 보고서에 80%·90% 추가 실행의 앱 내부 임계치 위반 직후 PID 종료 순서를 보강했고 사용자가 현 증거 기준 보고서 마무리를 요청했다. 새 `top` 실험은 반복하지 않으며 기존 OS 표본은 유지한다. 앱 시나리오·보호 분기는 추론이고 OS CPU 급상승과 Watchdog 보호 종료는 미입증이므로 REQ-003·TASK-003은 미완료다.

2026-10-28 사용량 관리 하네스 병합: 기존 PM 대화·자동 위임·미션 기록을 유지하고 관련 구간 읽기, 같은 TASK Implementer 재사용, 독립 Reviewer의 중복 검토 축소, 간결한 인계 규칙을 운영 문서와 템플릿에 반영했다. 프로젝트별 PM GPT-6 Sol / High와 Implementer·Reviewer Medium, TASK 마감 시 학습 정리는 그대로다. 런타임 설정은 변경하지 않았으며 현재 PM 채팅의 실제 모델·reasoning·속도는 이 문서 병합만으로 확인되지 않는다. 미션 상태와 다음 CPU 증거 과제는 아래 기록을 따른다.

2026-10-27 [TASK-006](tasks/TASK-006.md) 마감 완료: 공통 `monitor.sh`의 메모리 종료(128/40/false), CPU 임계치 기록 뒤 종료(512/80/false), 60초 생존 뒤 정리(512/40/false), 교착 대기 뒤 정리(400/40/true)를 사용자 실행 원본으로 확인했다. 마지막 교착 실행은 락 순환 대기 로그 뒤 약 52초간 PID 생존·RSS/CPU/로그 정체가 이어졌고 도구 정리 뒤 포트가 해제됐다. [REQUIRED 리뷰](reviews/REVIEW-TASK-006.md)의 Major-1/2·Minor-1 승인 수정과 [독립 재검토](reviews/REVIEW-TASK-006-FIX.md)의 새 finding 없음, [최종 학습 정리](../study-note.md#task-006-공통-관측과-실행-후-안전-정리)도 확인했다. 기존 2인자 호출·실패/중단·수동 정리는 정적 확인만 있고 실행 미검증이다. CPU OS 급상승·Watchdog 필수 증거는 여전히 부족하다.

2026-10-27 [TASK-005](tasks/TASK-005.md)의 공통 관측 명령·시간 제한 메모리 관측·시각/설정 기반 폴더 이름을 구현했다. 최초 REQUIRED 리뷰의 Major-1·Minor-1은 승인 수정과 독립 재검토에서 정적 해결됐고, 7개 과거 증거 폴더 이름·관련 링크 변경도 별도 독립 리뷰에서 Critical/Major/Minor가 없었다. 후속 TASK-006 공통 명령의 네 사용자 실행을 확인했다. 첫 시각 접두어 Reviewer 호출은 사용량 한도로 실패했고 같은 지정 모델의 재시도에서 결과를 회수했다.

2026-10-27 TASK-004 마감 완료. TASK-003 CPU 관측 도구 REQUIRED 재검토와 80%·40% 비교 보고서 RECOMMENDED 독립 재검토 완료, 새 finding 없음. 종료·60초 생존 차이는 기록했으나 OS CPU 과점유·Watchdog 근거는 미확보다.

TASK-001·TASK-002 완료. TASK-002 실패 경로 실행 검증은 2026-10-09 사용자 요청으로 생략하고 실행 미검증으로 남긴다. REQUIRED 리뷰·보완·정상 비교·학습 정리 완료, 추가 리뷰 SKIP. TASK-003 기존 CPU 관측·인자화와 이번 부모·후손 범위 관측을 확인했고 관측 도구 REQUIRED 독립 리뷰를 완료했다. CPU 필수 증거 부족과 나머지 회귀 검증이 남아 있다.

## Completed

- TASK-007 선택 보너스: 한 정상 실행의 로그 기반 FCFS형 가설 보고서, 사용자 선택에 따른 독립 리뷰 생략, 최종 학습 절·읽기 순서 정리. 실제 스케줄링 정책과 사용자 이해는 확인했다고 주장하지 않는다.
- 미션 원문 보존 및 요구사항 정리.
- REQ-001 사전 준비 및 부트 성공 확인.
- CSV 수집·column 조회·EXITED, 앱 로그와 시간 대조 확인.
- 기존 CSV 해시 보존, 파일 생성 실패 반환값 1 확인.
- MEMORY_LIMIT=49 실패 안내 및 변수 유지 확인.
- 관제 Ctrl+C 이후 앱 PID 12741 생존(SN, 00:11) 확인.
- REQUIRED 독립 리뷰 완료, Minor-1 반영 및 검증 완료. 추가 리뷰 SKIP.
- REQ-004 Deadlock: true의 A/B 락 순환 대기·작업 정체와 false의 작업 진행 비교, 보고서·두 리뷰·사용자 확인·최종 학습 정리 완료. 사용자 이해 완료는 미확인이다.
- TASK-006 공통 관측·자동 정리: 네 설정 경로의 사용자 실행, REQUIRED 리뷰·수정 재검토, 최종 학습 정리 완료. 기존 2인자와 이상 경로의 실행 검증은 미확인이다.

## 이전 TASK 결과

[TASK-002](tasks/TASK-002.md)의 [OOM 보고서](../reports/oom.md)는 128/300MB·CPU 40% 사용자 실행을 주 근거로 한다. 128MB는 MemoryGuard 자체 종료, 300MB는 MemoryWorker 정리 후 60초 관측 끝까지 생존했다. 이전 128/256MB 동일 작업의 17초→32초 비교는 TASK 기록에 남기며 보고서 주 근거와 구분한다.

## Next

- [TASK-007](tasks/TASK-007.md)은 보너스 보고서와 최종 학습 절 작성까지 마감했다. 사용자 이해 확인은 문서 작성과 구분한다.

- 세 보고서의 압축본을 사용자에게 제시하고, 평가 핵심 문서 변경에 대한 RECOMMENDED 독립 리뷰 진행/생략을 결정한다. 사용자가 확인하면 TASK-002 학습 절의 오래된 80%·17초→33초 설명도 최신 보고서와 맞춘다.

- [OOM 보고서](../reports/oom.md)의 128/300MB 수치·경고 종류·도구 정리 구분을 사용자가 확인하고, 문서 주 증거 교체에 대한 RECOMMENDED 독립 리뷰 진행 여부를 결정한다. 이후 [TASK-002 학습 절](../study-note.md#task-002-메모리-설정-전후-비교와-oom-보고)의 기존 비교 수치를 최종 보고서와 동기화한다.

- [OOM](../reports/oom.md)·[CPU](../reports/cpu.md)·[Deadlock](../reports/deadlock.md) 보고서에서 Git 제외 대상 `runs/`로 향하던 링크를 제거하고 실행 식별자·필요한 원문 발췌를 남겼다. 다음은 세 보고서의 제출 형태와 REQ-005·REQ-006의 남은 범위를 확인하는 것이다. CPU 필수 증거 미충족은 유지한다.

- [TASK-005](tasks/TASK-005.md): 처음 7개 원본의 시각·설정 기반 이름과 문서 링크를 갱신했다. 당시 mode별 `memory-observation.txt` 실행 검증은 후속 TASK-006의 단일 공통 산출물로 대체됐으며 과거 형식의 사용자 재실행을 요구하지 않는다. 파일 26개 해시 전후 일치는 Implementer 보고이고 이동 전 manifest의 독립 검증은 미수행이다.

- [TASK-003](tasks/TASK-003.md)의 512/80/false와 512/40/false 관측을 [CPU 보고서](../reports/cpu.md)에 비교하고 [RECOMMENDED 독립 재검토](reviews/REVIEW-TASK-003-CPU-REPORT.md#2026-10-27-비교-추가-독립-재검토)를 완료했다. Critical/Major/Minor 없음. 사용자의 후속 질문·보고서 확인을 기다린다. 40% 앱은 관측 종료 시 살아 있었으므로 다음 실행 전 PID·포트를 다시 확인한다.

- [TASK-004](tasks/TASK-004.md) 마감 완료. [Deadlock 보고서](../reports/deadlock.md)·[학습 절](../study-note.md#task-004-교착상태-관측과-멀티스레드-설정-비교)·README를 최종 결과로 동기화했다. 사용자 이해와 별도 신호·실패 검증은 미확인으로 보존한다.

1. [CPU 보고서 초안](../reports/cpu.md) 작성·원본 정적 대조 및 [RECOMMENDED 독립 리뷰](reviews/REVIEW-TASK-003-CPU-REPORT.md) 완료, 지적 없음. 추가 리뷰 SKIP. 사용자 보고서 확인 및 남은 증거 확보 방향 결정 대기. 512/80/false, PID 5286, 실행 기록부터 EXITED까지 약 34초(관제 구간 27초), top 최대 5%, 앱 임계치 위반 약 50.42%를 기록했다. 보호 종료를 시사하는 흐름과 미확인 내부 지표를 구분했으며 OS 과점유·Watchdog 입증 부족은 유지한다. 표시 모드만 바꾼 재실험은 예정하지 않는다.
2. 비교 근거: 첫 80% 실행은 37초 종료, 두 번째 40% 실행은 첫 RUNNING부터 사용자 kill에 따른 EXITED 관측까지 248초(18:05:18→18:09:26). 자연 종료 수명 비교로 해석하지 않는다. 인자 적용·부트·CSV 종료 수집은 확인했다. [TASK-003](tasks/TASK-003.md) 참조.

2026-10-08 재개: Implementer의 읽기 전용 안내를 회수했다. 정상 비교 comparison-B8CmgX의 원본 CSV·앱 로그 및 최종 종료 코드 0을 확인했다. 128/256MB 관측 시간은 18초/32초, 최고 RSS는 146,536/274,524 KiB다. 실패 주입은 별도 검증 환경과 구체적 계획 승인 후 진행하며 아직 수행하지 않았다. [재개 기록](WORKLOG.md#task-002-사용자-검증-안내-재개).

## Open Issues

- TASK-002 부트 표식 누락·before 저장 실패 경로는 사용자 선택으로 실행 검증 생략(정적 확인만). 정상 비교 comparison-B8CmgX 확인 완료. 별도 셸 종료 코드 출력은 전달받지 않았다.
- CPU 필수 증거 보완·최종 보고서, 전체 제출과 사용자 학습 목표 확인은 미완료다. Deadlock 실험·보고서·학습 정리는 완료했다.
- TASK-004 관측 도구의 Ctrl+C/TERM·자연 종료·관제 오류 경합은 실행 미검증이다. 정상 시간 만료·앱 유지·파일 수집은 두 사용자 실행에서 확인했다. 이 항목은 미션 Deadlock의 추가 필수 실험으로 확대하지 않는다.
- 512MB 실행의 작업 전환·CPU 임계치 판정 내부 이유는 미확인이다.
- 2026-10-13 첫 CPU 관측은 PID 4910, 첫 RUNNING→EXITED 37초. 앱 Current Load 50.58%에서 임계치 위반을 기록했지만 top 캡처는 3.0%(사용자 관찰 약 5%)이며 Watchdog·SIGTERM 명시는 없다. OS 과점유 및 보호 종료 입증은 미완료다.
- TASK-002 학습 노트 작성은 완료했으나 사용자 이해 완료는 별도로 확인한다.

## Recent Decisions

- OrbStack Linux 머신, Docker 미사용. 사용자 실행·AI 정적 검토.
- CSV 원본 저장 및 column 화면 조회. runs/ 원본은 Git 제외이므로 제출 증거는 후속 보고서에 별도 반영한다.
- TASK-002는 기존 준비·관제 도구를 재사용하는 순차 비교 스크립트로 진행한다. 비교 출력 로그 저장 추가 계획을 승인받았다.
- 학습 노트는 구현마다 수정하지 않고 TASK 마감 시 최종 코드 기준으로 한 번 정리한다.
- 사용자 실행 결과는 저장된 로그와 연결된 원본으로 전달할 수 있다. 터미널 전체 복사를 요구하지 않는다.
- 별도 지정이 없으면 runs의 실행 시각이 최신인 디렉터리를 확인하고 부트 설정·PID와 대조한다.

## Current Task

[TASK-003](tasks/TASK-003.md) — CPU 필수 증거·보고서 후속 판단 대기. [TASK-006](tasks/TASK-006.md)은 공통 `monitor.sh`·안전 정리의 네 사용자 실행, REQUIRED 리뷰와 최종 학습 정리까지 마감했다. 기존 2인자 호출·이상 경로는 실행 미검증이다.

[TASK-005](tasks/TASK-005.md) — 시각·설정 기반 폴더와 공통 명령 구현, 리뷰 수정 및 과거 7개 증거 폴더/링크 변경 독립 리뷰 완료. mode별 실행 형식은 후속 TASK-006에서 단일 공통 명령으로 바뀌었다.

[TASK-003](tasks/TASK-003.md) — 관측 도구 REQUIRED 재검토, 80%·40% 사용자 실행 비교와 [CPU 보고서](../reports/cpu.md) RECOMMENDED 재검토 완료. 사용자 보고서 확인·후속 질문 대기, CPU 필수 증거는 미완료다. [TASK-004](tasks/TASK-004.md)는 2026-10-27 마감 완료했다. 현재 모델 정책은 PM GPT-6 Sol / High, Implementer·Reviewer GPT-6 Sol / Medium이다.

[TASK-003](tasks/TASK-003.md) — 사용자 승인으로 준비 도구의 메모리·CPU·멀티스레드 3개 인자, 메모리 비교 호출 호환, README 사용법을 반영했다. [REQUIRED 리뷰](reviews/REVIEW-TASK-003.md) 지적 없음. 인자 정상 경로와 두 번째 관측은 확인했고, OS CPU 급상승·Watchdog 증거 보완 및 나머지 회귀 검증 대기다. TASK-002는 사용자 검증 생략 결정과 한계를 기록하고 마감했다.

이전 [TASK-001](tasks/TASK-001.md)은 완료이며 REQUIRED 독립 [리뷰](reviews/REVIEW-TASK-001.md)·Minor-1 처리 완료, 추가 리뷰 SKIP 상태를 유지한다. TASK-002 착수 전 작업 트리는 clean이고 HEAD는 `48438ce11b3e8c311b142d670515a50ac1f55e1a`였다. 이번 세션에서 Git 쓰기 작업은 하지 않았다.

## Harness Update

사용자가 제공한 갱신 템플릿의 공통 지침·학습 템플릿을 반영했다. 미션 원문·요구사항·진행 이력·실제 TASK·리뷰는 초기화하지 않았다. 2026-09-30 사용자 승인으로 공통 지침·역할 프롬프트·템플릿을 변경했다. 앞으로 단일 [study-note.md](../study-note.md)의 해당 TASK 절은 구현·필요한 리뷰와 수정·사용자 검증 완료 후 TASK 마감 시 한 번 작성·정리한다. 기존 초안과 사용자 메모는 보존한다.

### 2026-10-08 승인 기반 반자동 전환

- 당시 단계: 하네스 문서 전환·읽기 전용 위임 및 결과 회수 확인 완료. 당시 기능 TASK는 TASK-002 사용자 검증 대기였으며 현재 상태는 위 Current Task를 따른다.
- 승인 범위: 사용자 “진행해봐”로 제시한 기존 하네스 11개 문서의 전환 계획 및 읽기 전용 위임 확인 승인. 프로젝트 기능·미션 원문·기존 실험 증거·학습 본문 수정은 제외한다.
- 운영: 사용자 대화·승인은 PM으로 통일. Implementer 계획과 구현을 분리하고 새 Reviewer로 독립 검토한다. PM을 포함해 단일 작성자로 순차 갱신한다.
- 결과 위치: [운영 절차](WORKFLOW.md), [모델 지정·확인 한계](MODEL_POLICY.md), [전환 기록](WORKLOG.md), [TASK-002 복구 상태](tasks/TASK-002.md#execution-state).
- 확인 결과: `gpt-6-sol` / `medium` Implementer 계획·후속 응답과 새 `gpt-6-luna` / `medium` Reviewer 결과를 회수했다. 두 호출 모두 `fork_turns="none"`. Reviewer 지적 없음. 위임 전후 추적·Git 제외가 아닌 미추적 파일 28개의 해시가 동일했다.
- 확인 한계: 요청 설정은 도구가 수락했으나 실행 모델·reasoning 메타데이터와 부모 PM의 Astra 실행 여부는 별도 확인하지 못했다. 읽기 전용은 지침이며 OS 권한 차단을 검증한 것이 아니다. 실제 구현·실행 테스트·실패 주입·세션 재시작 복구는 이번 확인 범위 밖이다.
- 당시 다음 행동: PM 세션에서 TASK-002 사용자 실행 결과를 확인하는 것이었다. 현재 다음 행동은 위 Next를 따른다. PM 모델은 사용자 선택 화면에서 Astra 여부를 확인할 수 있다.
