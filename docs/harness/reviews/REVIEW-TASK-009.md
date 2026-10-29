# Review: TASK-009

- 대상: [TASK-009](../tasks/TASK-009.md), [미션 원문](../MISSION.md), [요구사항](../REQUIREMENTS.md).
- 기준점: `/tmp/task009-baseline-quboempy`의 수정 직전 사본 대비 현재 [README](../../../README.md), [OOM](../../reports/oom.md), [CPU](../../reports/cpu.md), [Deadlock](../../reports/deadlock.md), [REQUIREMENTS](../REQUIREMENTS.md) 다섯 파일. HEAD 전체 diff를 이번 TASK 변경으로 간주하지 않았다.
- 방법과 한계: 독립 정적 리뷰. 관련 [monitor.sh](../../../monitor.sh), [prepare-env.sh](../../../prepare-env.sh), [cpu_precise.c](../../../cpu_precise.c) 및 기존 [TASK-003](../tasks/TASK-003.md)·[WORKLOG](../WORKLOG.md)의 필요한 기록을 읽었다. `runs/` 원본이 현재 없어 보고서 발췌의 실제 원본 일치 여부는 재검증할 수 없으며 앱·스크립트·테스트는 실행하지 않았다. Reviewer 요청 설정은 `gpt-6-sol` / `medium` / `fork_turns="none"`이고 실제 실행 모델 메타데이터는 별도로 확인하지 않았다. 구현 대화는 상속하지 않았다.

## Critical

없음.

## Major

없음.

## Minor

### Minor-1 — README 절 변경으로 기존 학습 노트 링크 두 건이 끊김

- 위치: [README](../../../README.md) 32~58행의 `실행 방법` 절, [학습 노트](../../study-note.md) 205·324행.
- 문제·근거: 수정 직전 README의 `설정값만으로 공통 관측` 제목이 제거됐으나 학습 노트의 두 링크는 여전히 `../README.md#설정값만으로-공통-관측`을 가리킨다. 현재 README에는 해당 앵커가 없어 메모리·교착 학습 절에서 현행 실행 안내로 바로 이동할 수 없다.
- 영향·조건: 학습 노트의 해당 링크를 누르는 경우 문서 상단 또는 유효하지 않은 위치로 이동할 수 있다. 보고서 증거와 실행 명령 자체에는 영향이 없다.
- 최소 수정 방향: 마감 시 학습 노트 두 링크를 현행 `README.md#실행-방법`으로 갱신하거나 README에 호환 앵커를 복원한다. 학습 노트는 이번 승인된 다섯 파일 범위 밖이므로 PM이 기존 마감 동기화 단계에서 처리 범위를 결정한다.

## Good

- 세 보고서의 원문 필수 네 절과 기존 앱 로그·OS 표본·Before/After 행이 유지됐다. 이번 변경의 재현 명령은 [monitor.sh](../../../monitor.sh)의 3/4인자 형식·15~300초 범위와 맞는다.
- [CPU 보고서](../../reports/cpu.md) 40~57·92~98행은 추가 80% 실행의 앱 `Current Load`, C 수집기의 약 0.1초 45.94%·54.41%, 별도 약 1초 4.19%, `monitor.csv`의 수명 평균 0.8%를 구분한다. [cpu_precise.c](../../../cpu_precise.c)의 `make_row`·`record_sample` 및 기존 [TASK-003](../tasks/TASK-003.md)·[WORKLOG](../WORKLOG.md) 기록과 측정 설명이 부합한다. 40% After에 같은 C 수집 결과가 없음을 밝히고 OS CPU 완화 효과로 비교하지 않는다.
- CPU의 앱 자체 보호 종료는 로그 순서에 따른 **해석**으로 표현하고 Watchdog 조치·종료 신호 발신자·시스템 지연은 미입증으로 남겼다. 사용자 지시를 새로운 관측 증거로 사용하지 않았고, [REQUIREMENTS](../REQUIREMENTS.md)의 REQ-003·005·006 미완료와 일치한다.
- [OOM](../../reports/oom.md)과 [Deadlock](../../reports/deadlock.md)은 적용한 설정 조치와 미적용 근본 제안을 분리한다. OOM의 관측 상한·작업 경로 차이와 Deadlock의 PID·`ps -L` 스레드 대기 근거 및 교착 네 조건의 추론 한계를 보존했다. 요청 범위 밖의 `/proc` 커널 콜스택 결과는 추가하지 않았다.
- [README](../../../README.md)는 현재 공통 호출, 기존 2인자 관제, 자동·수동 정리 차이를 안내한다. 구현·실패 경로의 상세 설명을 기존 TASK·학습 문서로 연결하고, 원본이 Git에서 제외됨을 밝힌다.

## PM Disposition

### Minor-1

Decision: ACCEPT

Reason: README 구성 변경으로 생긴 실제 링크 단절이다. 사용자가 2026-10-29 “두 링크 수정 승인”으로 승인했다. 같은 Implementer가 학습 노트의 두 링크 대상만 `../README.md#실행-방법`으로 바꾸며 본문·학습 이력은 보존한다. 반영 결과와 최종 정적 확인은 TASK-009에 기록한다.

반영 확인: 두 링크 수정 완료. PM이 수정 직전 사본과 바이트 대조하여 두 대상만 바뀌었고 본문·CRLF가 유지됐음을 확인했다. 추가 Review Decision: SKIP — 단순 링크 교정이며 기존 독립 리뷰 이후 다른 내용 변경이 없다. 앱 실행·테스트는 수행하지 않았다. 사용자 최종 문서 확인은 대기한다.

## 2026-10-29 후속 가독성 개선·중단 복구 최종 검토

- 대상: [TASK-009](../tasks/TASK-009.md)의 승인된 일곱 파일 재개 계획 및 중단 후 복구. [README](../../../README.md), [OOM](../../reports/oom.md), [CPU](../../reports/cpu.md), [Deadlock](../../reports/deadlock.md), [Scheduling](../../reports/scheduling.md), [학습 노트](../../study-note.md), [REQUIREMENTS](../REQUIREMENTS.md)를 검토했다.
- 기준점과 한계: HEAD `ac8afa5` 전체 diff에는 선행 사용자 변경이 포함되어 이번 변경으로 간주하지 않았다. 최초 편집 전 임시 사본은 없어 전체 가독성 편집의 바이트 단위 보존 여부는 확정할 수 없다. 승인 계획·현재 문서·관련 Git 이력·기존 학습 기록을 대조했다. OOM 주 비교는 `git show d3ef9b9:docs/reports/oom.md`와 대조했다. `/tmp/task009-recovery-2b7qbzvl`은 가독성 편집이 이미 존재한 복구 시점 사본이며 복구 이후 최소 변경 확인에만 사용했다.
- 방법: 구현 대화 미상속 독립 정적 검토. [미션](../MISSION.md) §2~5, 관련 요구사항, [WORKFLOW](../WORKFLOW.md)의 안전성·리뷰 기준과 현행 실행 입력에 필요한 [monitor.sh](../../../monitor.sh)·[prepare-env.sh](../../../prepare-env.sh)를 확인했다. 앱·스크립트·테스트를 실행하거나 새 실험을 수행하지 않았다. 현재 `runs/` 원본이 없어 실행 원본과의 재대조는 불가하다.
- 모델: 사용자 일회성 예외 승인에 따른 요청 설정 `gpt-6.1-sol` / `medium` / `fork_turns="none"`. 호출 수락과 실제 실행 모델 메타데이터 검증을 구분하며, 모델 정책 파일은 변경하지 않았다.

### Critical

없음.

### Major

없음.

### Minor

없음. 후속 검토에서 필요한 최소 수정 사항을 발견하지 못했다.

### Good

- 네 보고서는 각각 네 절과 Description 세 문장을 갖추고, 설명을 짧은 보고서체로 정리했다. 세 장애 보고서의 적용 조치·관측 결과와 미적용 근본 제안을 분리했다.
- [OOM](../../reports/oom.md) 14~39·50~59행의 PID 8661/8790·Heap 150/275MB·RSS·MemoryGuard 원문은 지정 Git 기록과 일치한다. CPU 80%·false의 128/256MB 두 실행 모두 종료했으며 17→33초를 4절에서 첫 RUNNING→EXITED 기준으로 표시했다. 후속 CPU 40%의 128/300MB 앱·CSV·관측 요약은 [학습 노트](../../study-note.md) 285~340행에 분리되어 있다.
- [CPU](../../reports/cpu.md) 26~37·54~68행은 별도 0.1초 45.94/54.41%와 약 1초 4.19%, 앱 Load와 관제 수명 평균을 구분한다. 기존 80/40% 비교를 유지하고 작업 경로·수집법 차이를 밝혔으며 Watchdog·SIGTERM 발신자·실제 지연을 직접 확인한 것으로 쓰지 않았다.
- [Deadlock](../../reports/deadlock.md) 14~26·41~59행은 PID·스레드·CPU 정체·BLOCKED·락 순환과 설정 전후 작업 진행을 유지한다. 발췌한 ps 열의 값은 [학습 노트](../../study-note.md) 474~480행의 전체 표와 일치하고 CPU/MEM 상세 비교도 485~494행에 남아 있다.
- [Scheduling](../../reports/scheduling.md) 24~36행은 FCFS·RR·Priority의 구별 한계, 실제 조치 없음, FCFS형의 장단점·서비스 적합성을 명시한다. 전체 진행 원문과 밀리초 표는 [학습 노트](../../study-note.md) 621~649행에 보존했다.
- [README](../../../README.md) 18~47행은 현재 실행 명령·설정 제약·정리 흐름과 네 보고서 링크를 제공한다. 학습 노트 두 링크의 `#실행-방법` 대상이 유지되고 [REQUIREMENTS](../REQUIREMENTS.md)의 REQ-003/005/006 미완료와 문서 표현이 일치한다. 제외된 커널 콜스택 결과나 새 미확인 안내는 추가되지 않았다.
- File Safety / Data Integrity: 복구 이후 OOM·CPU·Deadlock의 변경은 Description 축약·OS 원리·측정 기준 보완으로 한정됐다. README·Scheduling·학습 노트·REQUIREMENTS는 복구 사본과 바이트가 같았다. 이번 리뷰는 이 문서의 본 절만 추가했으며 이전 리뷰·PM 판단을 보존했다. 기능 코드·메모리 관리·파괴적 동작·credential 변경은 검토 대상에 없다.

### PM Disposition

최종 검토 결과 수용. Critical/Major/Minor 모두 0건으로 수정 대상 finding 없음. OOM 지정 Git 기록과 CPU·Deadlock·Scheduling 증거의 연결, 기존 학습 자료 보존 및 최초 비교 사본 부재라는 검토 한계를 확인했다. 사용자 최종 문서 확인·미션 전체 완료와 구분한다. 추가 Review Decision: SKIP — 이 리뷰 이후 내용 문서 변경 없이 결과·상태 기록만 정리한다.

## OOM 300MB 후속 관측 추가 검토

- 범위·기준: [TASK-009](../tasks/TASK-009.md)의 사용자 후속 지시에 따라 `/tmp/task009-oom300-htu9wywj/docs/reports/oom.md` 수정 직전 사본과 현재 [OOM](../../reports/oom.md) 4절의 diff만 검토했다. 같은 TASK의 일회성 `gpt-6.1-sol` / `medium` 예외를 유지하며 실제 실행 모델 메타데이터를 별도로 검증한 것은 아니다.
- 방법·한계: [학습 노트](../../study-note.md) 285~342행에 보존된 기존 발췌를 대조했다. 현재 실행 원본은 없으므로 새 원본 대조나 실행 검증이 아니다. 앱·스크립트·테스트·새 실험·Git 쓰기를 수행하지 않았다.

### Critical

없음.

### Major

없음.

### Minor

없음. 필요한 최소 수정 사항 없음.

### Good

- [OOM](../../reports/oom.md) 61~67행은 실제 권장 문구 `Recommend Over 256MB`와 256MB 설정의 종료 Heap 275MB를 구분한다. 300/40/false·PID 8176의 정리·회복 네 로그는 [학습 노트](../../study-note.md) 315~323행의 보존 문자열과 일치한다.
- [OOM](../../reports/oom.md) 70~75행의 Heap 300→25MB·16:30:14→16:30:19와 RSS 300,160→18,516 KiB·16:30:14→16:30:15는 학습 노트 319~330행과 일치한다. 60초 컷오프 생존 후 도구 정리는 학습 노트 310·335~340행의 기록과 맞는다. 기존 CPU 80% 주 비교와 조건·작업 경로가 다른 별도 실행임을 밝히고 한도만의 인과 효과·영구 해결로 확대하지 않았다.
- 수정 직전 사본 대비 1~3절·128/256MB 표·17/33초 기준·미적용 근본 제안은 유지됐다. 추가 내용은 4절 안의 보고서체·표·기존 학습 이력 링크로 한정되며 이전 리뷰와 PM 판단도 보존했다.

### PM Disposition

결과 수용. Critical/Major/Minor 0건, 수정 finding 없음. 4절 추가 내용과 보존된 학습 원문의 일치 및 별도 실행의 해석 한계를 확인했다. 추가 Review Decision: SKIP — 이후 내용 변경 없이 결과 기록만 정리한다. 사용자 최종 문서 확인과 미션 전체 완료는 별개다.
