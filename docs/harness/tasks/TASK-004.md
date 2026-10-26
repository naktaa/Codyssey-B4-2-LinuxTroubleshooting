# TASK-004: 교착상태 관측과 멀티스레드 설정 비교

## Goal

PID가 살아 있으나 작업이 정체된 상태를 관측하고, 스레드 간 자원 대기를 로그와 OS 도구로 추론한다. MULTI_THREAD_ENABLE 변경 전후 재현·회피 결과를 보고서로 정리한다.

## Context

- 사용자 “일단 하위 에이전트 패널은 딱히 없어서 그냥 하자. 다음 진행”으로 제안된 Deadlock Step 및 기존 내장 위임 방식 진행 승인.
- TASK-003 CPU 보고서·독립 리뷰는 완료했으나 CPU 필수 증거 부족은 그대로 남긴다. CPU 완료로 간주하지 않는다.
- 난이도 MEDIUM. 현재 Implementer·Reviewer 설정은 사용자 변경 정책에 따라 `gpt-6.1-sol` / `medium`이다. 이전 `gpt-6-sol` 호출 기록은 이력으로 보존한다.
- Review 예상 RECOMMENDED: 보고서의 증거·원인 해석 검토. source 변경이 필요하면 별도 계획 승인과 위험 재평가가 필요하다.
- 구현 계획 승인: Scope의 최초 구현 승인 및 아래 리뷰 수정 승인 기록을 따른다.

## Execution State

- 현재 단계: 사용자 검증 대기(보고서 확인). Deadlock 보고서 RECOMMENDED 독립 리뷰 완료, Critical/Major/Minor 없음. 관측 도구의 REQUIRED 수정 재검토와 true/false 사용자 실행 비교도 완료했다. 최종 학습 정리는 대기다.
- 기준점: HEAD `d47a7bd`. TASK 작성 직전 작업 트리는 clean이었다. 이전 CPU 보고서·독립 리뷰·상태 기록을 보존한다. PM이 Git 쓰기를 수행하지 않았다.
- 위임: 최초 계획·구현은 `gpt-6-sol` / `medium`으로 완료했다. 이번 수정과 새 독립 Reviewer는 각각 `gpt-6.1-sol` / `medium`, `fork_turns="none"`으로 생성해 결과를 회수했다. 도구가 지정 설정을 수락했으며 실제 실행 모델 메타데이터는 별도 확인하지 않았다.
- 다음 행동: 사용자 보고서 확인 → 기능 완료 판단 및 최종 학습 정리. 신호 중단·실패 경합 등 별도 도구 검증은 미확인으로 보존하며 미션 필수 실험으로 확대하지 않는다. 앱·테스트 실행은 사용자 담당이다.

### 보고서 작성 승인

- 사용자 “작성 시자ㅣㄱ”을 앞서 제시·회수한 신규 `docs/reports/deadlock.md` 한 파일 작성 계획의 승인으로 확인했다.
- 범위: 현상·증거·원인·조치 및 검증 네 절, 실제 원본 발췌·상대 링크·설정/시각/PID·60초 전후 비교, 순환 대기 분석과 해석 한계를 포함한다. 코드·원본·README·학습 노트는 이번 작성에서 변경하지 않는다.
- 위임: Implementer `gpt-6.1-sol` / `medium`의 기존 세션에 승인 범위를 전달한다. 보고서 정적 self-check와 실제 위치 설명을 회수하며 앱·테스트 실행은 하지 않는다.
- 결과: [Deadlock 보고서](../../reports/deadlock.md) 한 파일 작성 완료. 네 절·로그 발췌·수치·10개 상대 링크 존재·해석 한계를 정적으로 확인했다. PM이 두 실행 원본과 문서를 대조했다. 코드·README·원본·학습 노트 변경 및 추가 실행 없음.
- Review Decision RECOMMENDED: 사용자 “진행” 승인으로 새 Reviewer `gpt-6.1-sol` / `medium`, `fork_turns="none"`의 [보고서 독립 리뷰](../reviews/REVIEW-TASK-004-DEADLOCK-REPORT.md)를 회수했다. Critical/Major/Minor 없음, PM Disposition 완료. 도구 지정값 수락과 실제 실행 메타데이터 확인은 구분한다. 추가 리뷰 SKIP(보고서 변경 없음). 기존 REQUIRED 리뷰는 관측 도구 검토이며 이번 보고서 검토와 구분한다.

### 2026-10-26 false 비교 사용자 검증

- 사용자가 true 앱을 종료하고 포트 해제 후 같은 명령의 멀티스레드 인자만 false로 바꿨다고 확인했다. `runs/run-2026-10-26_18-00-02-1munWl` 네 원본을 대조했다. 설정 512/40/false, 60초 관측, launcher10476·자식10481, 부트 성공·반환값0, 관측 종료 시 두 PID와 포트 생존을 확인했다.
- thread-observation의 같은 0/15/30/45초 시점에서 앱 로그가 계속 진행됐다. 작업 TID10512/10513은 do_select 또는 실행 상태였고 메인 TID10481의 futex_wait만으로 교착을 판단하지 않는다. false여도 OS 스레드는 존재하므로 완전한 단일 스레드 전환이라고 설명하지 않는다.
- CSV 18:00:03~18:01:02에서 RSS18,500→504,780KiB, 프로세스 수명평균CPU5.0→1.8%, 전 행 RUNNING을 확인했다. 앱은 스케줄러 작업 완료, 메모리 작업 진행, CPU40% cooldown·재상승을 기록했다. 관측 이후에도 로그가 이어졌으며 18:01:06의 cleanup은 CSV 수집 이후 자료로 구분한다.
- true는 A/B 락 순환 대기와 로그 정체, false는 Healthy System Monitoring 경로에서 지속 작업이 관측됐다. 설정 외 입력은 같지만 앱 경로가 달라졌으며, 이 결과는 관측 구간에서의 교착 회피이지 내부 락 알고리즘 수정이나 영구적인 무장애를 증명하지 않는다.
- Review Decision SKIP: 사용자 원본 대조·상태 갱신만. 기본 정상 경로는 두 실행에서 확인했으나 Ctrl+C/TERM·자연 종료·실패 경합 등은 여전히 미검증이다. 보고서 및 최종 학습 정리는 미완료다.

### 2026-10-26 true 첫 관측 사용자 검증

- 사용자 실행 `bash ./run-deadlock-observation.sh 512 40 true` 및 반환값 0 확인. 원본 `runs/run-2026-10-26_17-54-55-kFiIRQ`의 app.log·agent_app.log·monitor.csv·thread-observation.txt 네 파일을 PM이 직접 대조했다. 부트 성공, launcher 9870·자식 9875, 사용자 종료 출력에서 두 PID 생존 및 15034 LISTEN을 확인했다. AI는 앱을 실행하거나 종료하지 않았다.
- 17:55:03 Worker-Thread-1은 Shared_Memory_A, Worker-Thread-2는 Socket_Pool_B 락을 각각 획득했다. 17:55:05.064부터 Thread-1은 B, Thread-2는 A를 WAITING/BLOCKED로 기록했고 앱 로그의 추가 진행은 없었다. 순환 대기 관계를 추론할 직접 로그 근거다. 로그 스레드 이름과 OS TID의 개별 대응은 확인하지 않았다.
- 17:55:11·26·41 스레드 표에서 TID 9875/9933/9934가 모두 futex_wait, 두 작업 TID의 평균 CPU 0.0%를 유지했다. CSV는 끝까지 RUNNING이며 17:54:56~17:55:56 수집됐다. 프로세스 평균 CPU는 4.0%에서 0.0%로 감소했으며 증가하는 과점유가 아니다.
- RSS는 초기 18,352 → 18,440 KiB 유지 후 17:55:41부터 18,148 KiB로 소폭 감소했다. 완전히 불변이라고 쓰지 않으며 지속적인 증가 없이 낮은 범위에 머물렀다. 낮은 CPU만이 아니라 락 점유·상대 락 대기·반복 스레드 상태·로그 정체를 종합해 교착상태 재현 근거를 확보했다.
- 정상 수집·시간 만료 후 관제 정리·앱 유지 경로의 사용자 검증은 확인했다. Ctrl+C/TERM·자연 종료·관제 오류 경합을 검증한 것은 아니다. false 비교·보고서·최종 학습 정리는 아직 미완료다.
- Review Decision SKIP: 사용자 실행 원본 대조와 상태 기록만 수행. 기존 REQUIRED 수정 재검토 완료는 유지한다.

### 리뷰 수정 승인

- 승인 근거: 사용자 “그러면 수정하면 돼” 및 “하네스 문서에 변경 반영하고 task004 수정도 시작”. 앞서 제시한 관측 스크립트 한 파일의 Major-1/Minor-1 수정과 상태 문구 정리를 승인했다.
- 범위: 정상 관제 종료 0 또는 스크립트가 의도한 TERM 종료 143만 허용하고 다른 실패는 정상으로 표시하지 않는다. INT/TERM 중단은 각각 130/143으로 반환한다. 앱 유지 정책·관측 형식·기존 도구를 유지한다.
- 하네스 변경: PM `gpt-6.1-sol` / High, Implementer·Reviewer `gpt-6.1-sol` / Medium으로 고정한다. 공통 정책·역할 프롬프트·템플릿의 현재 규칙만 갱신하고 과거 실행 기록은 보존한다.
- 수정 결과: [관측 스크립트](../../../run-deadlock-observation.sh) INT/TERM trap, 중단된 wait의 최종 결과 보존, 관제 종료 상태 판정, 최종 반환값을 수정했다. 앱·기존 준비/관제 도구·로그 형식 변경 없음. 정적 self-check와 PM diff 대조 완료.
- Review Decision: REQUIRED로 변경 범위 [독립 재검토](../reviews/REVIEW-TASK-004.md)를 실시했고 Major-1/Minor-1 해결 및 새 finding 없음을 확인했다. 추가 리뷰 SKIP(재검토 후 source 변경 없음). 정상·자연 종료·중단·실패 경합의 실제 실행은 미검증이며 최종 학습 정리는 대기다.

## 회수한 첫 관측 계획

### 단일 관측 스크립트 구현·리뷰

- [run-deadlock-observation.sh](../../../run-deadlock-observation.sh) 신규 작성 및 [README](../../../README.md) 사용법 추가 완료. 시각별 표·마지막 로그 8줄과 CSV를 저장한다. Implementer 정적 self-check와 PM 실제 파일 대조 완료, 앱·테스트 실행 없음.
- 최초 Review Decision REQUIRED: 파일 저장·백그라운드 관제 수명 처리. 새 Reviewer `gpt-6-sol` / `medium`, `fork_turns="none"`의 [독립 리뷰](../reviews/REVIEW-TASK-004.md)에서 Major-1/Minor-1을 ACCEPT했다. 이후 승인된 수정·재검토 결과는 위 절을 따른다.
- 관측 스크립트 한 파일에서 정상 관제 0 또는 의도한 TERM 종료 143만 허용하고 INT/TERM 중단 코드 130/143을 구분하도록 수정했다.

- 기존 도구로 512/40/true 첫 실행. 과거 512/40/false가 수동 종료까지 유지된 점을 참고해 CPU 임계치 종료 간섭을 줄일 후보로 선택했으며 재현은 보장하지 않는다.
- 단일 터미널에서 `bash ./run-deadlock-observation.sh 512 40 true`를 실행한다. PID·run_dir를 자동으로 얻어 CSV와 프로세스/스레드 표·마지막 앱 로그를 저장한다. 기본 60초에서 15초 간격 네 번 관측하며 표본 간 범위는 약 45초다. 선택 시간은 15~300초의 15초 배수다. 파일은 noclobber로 기존 내용을 보존한다.
- wchan은 대기 위치 참고값이며 락 소유자를 직접 입증하지 않는다. PID 생존·자원/로그 정체·스레드별 점유/대기 관계를 함께 확인한다. 낮은 CPU와 S 상태만으로 교착을 단정하지 않는다.
- 기본 시간 만료 시 관제를 정리하고 앱은 유지한다. Ctrl+C 중단 시 부분 증거와 코드 130, TERM 중단 시 143을 반환한다. 다음 실행 전 실제 PID·포트 상태와 앱 종료 필요성을 확인한다.
- 초기 실행 안내의 Review Decision은 SKIP이었으며 이후 자동화 구현·수정은 위 REQUIRED 리뷰 결과를 따른다. 보고서 작성 시 증거 해석 리뷰를 별도로 판단한다.

## Requirements

- [MISSION §2·§4](../MISSION.md), [REQ-004·REQ-005](../REQUIREMENTS.md): PID 존재, CPU/MEM 정체, 스레드 상태, 마지막 대기 로그 및 자원 대기 추론 근거, MULTI_THREAD_ENABLE 전후 비교, 네 절의 장애 보고서.
- REQ-006: 교착상태와 무응답 진단을 설명한다. CPU가 낮거나 로그가 잠시 멈춘 것만으로 교착상태를 확정하지 않는다.

## Constraints

- Linux 일반 사용자 및 미션 환경변수 범위를 지킨다. 현재 사용자가 제공한 환경은 논리 CPU 6개·KVM이며 OrbStack이라고 단정하지 않는다.
- 앱 실행·테스트·종료는 사용자 담당. PID와 실행별 경로를 대조하고 기존 프로세스·증거를 보존한다.
- 바이너리 수정·디컴파일·역공학 금지. 표준 도구와 기존 준비·관제 스크립트를 우선한다.
- 비교에서는 멀티스레드 설정만 변경하고 나머지 조건을 고정한다. 재현 성공이나 로그 문구를 미리 가정하지 않는다.
- 실행 안내 전 미션 단계·목적·측정 대상·충족 기준을 설명한다. 실행 중 앱의 안전한 관측 종료와 후속 실행 조건도 구분한다.

## Scope

- 후속 승인: 사용자 “txt에도 로그 길게 남기는거면 가독성 좋은 형식으로 보게 해줘 csv 같은것도 좋고. 그게 아니라면 구현 시작”으로 앞서 제시한 신규 `run-deadlock-observation.sh` 및 README 변경 계획 승인. 세 필수 인자(메모리/CPU/멀티스레드), 선택 관측시간(기본 60초), 기존 준비·관제 도구 재사용, 앱 자동 종료 없이 관제만 정리하는 정책을 적용한다. 스레드 관측은 시각별 구분·열 제목이 있는 표와 마지막 로그 일부로 읽기 쉽게 저장하며 기존 CSV를 유지한다. 기존 source·원본·의존성 변경은 제외한다.

- 기존 도구를 이용한 재현 후보·관측 절차 제안, 사용자 원본 대조, 결과에 따른 회피 조건 비교.
- 승인 후 Deadlock 보고서 및 필요한 README·상태 기록 갱신, TASK 마감 시 학습 정리.

## Out of Scope

CPU 추가 실험, 바이너리 내부 분석, 승인된 단일 관측 스크립트 외 신규 자동화 도구·의존성, Git 쓰기·제출, 무관한 source 수정.

## Acceptance Criteria

- [x] 살아 있는 대상 PID와 로그·설정·시각을 연결한다.
- [x] 시간 간격을 둔 CPU/MEM·스레드 관측과 로그 정체를 확보한다.
- [x] 마지막 로그 및 스레드/락 대기 근거로 교착상태를 추론하고 한계를 명시한다.
- [x] MULTI_THREAD_ENABLE 전후 재현·회피 결과를 같은 기준으로 비교한다.
- [x] 현상·증거·원인·조치 및 검증 네 절의 보고서를 실제 증거로 작성한다.
- [ ] 필요한 리뷰·사용자 검증·최종 학습 정리를 마친다.

## Relevant Files

- [prepare-env.sh](../../../prepare-env.sh), [monitor.sh](../../../monitor.sh), [README](../../../README.md).
- [관측 스크립트](../../../run-deadlock-observation.sh), [리뷰·재검토](../reviews/REVIEW-TASK-004.md).
- [CPU TASK](TASK-003.md), [CPU 보고서](../../reports/cpu.md): 기존 관측 및 한계 참고.
- [Deadlock 보고서](../../reports/deadlock.md).

## Implementation Notes

관측 시작 조건과 시간 간격·도구는 Implementer가 기존 동작을 확인한 뒤 제안한다. 낮은 CPU나 sleeping 상태만으로 순환 대기를 확정하지 않는다.

## Learning Deliverable

기능·리뷰·사용자 검증 완료 후 [학습 노트](../../study-note.md)에 PID 생존과 종료의 차이, 스레드와 락, 교착상태 조건, 관측·추론의 구분, 설정 비교를 최종 결과 기준으로 정리한다. 진행 중 작성하지 않는다.
