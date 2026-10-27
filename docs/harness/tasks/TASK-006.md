# TASK-006: 공통 증거와 관측 후 앱 정리

## Goal

설정값만 입력하는 [monitor.sh](../../../monitor.sh) 명령으로 세 장애의 미션 근거를 일관되게 수집하고, 수집 결과에서 관측된 상태를 설명하며, 이번 실행의 앱 프로세스를 관측 후 정리하고 포트 해제를 확인한다.

## Context

- 사용자는 CPU 범위 파일이 너무 길고, 장애 종류별 명령 인자와 산출물 이름이 달라 혼란스럽다고 보고했다. 기존 [TASK-005](TASK-005.md)의 mode 선택 명령은 사용자 검증 중이며, 이 요청은 그 경계를 바꾸는 후속 단계다.
- 사용자 후속 질문에 따라 `monitor.sh`를 유일한 관측 로직과 권장 사용자 명령으로 두는 계획을 검토했다. 기존 `monitor.sh PID CSV경로` 2인자 호출은 메모리 비교 등에서 사용 중이므로 유지하고, 새 설정값 3/4인자 호출과 구분한다. 별도 관측 모듈은 만들지 않는다.
- [kill-agent-leak.sh](../../../kill-agent-leak.sh)는 사용자 미추적 파일이다. 독립 읽기 전용 검토 결과, 현재 UID 전체의 `comm`/명령행 부분 문자열 검색이 다른 실행까지 TERM/KILL할 수 있고, 재검색 시 새 PID 편입·PID 재사용 및 `ps`/`ss` 실패의 성공 오인이 가능하다. 이 스크립트는 자동 정리에 연결하지 않는다.
- 설정값은 장애 진단 자체가 아니다. 실행 로그와 OS 관측이 모호하거나 겹치면 단일 장애 유형을 임의 확정하지 않는다.
- 난이도: HIGH — 공통 관측 흐름, 증거 형식, 프로세스 종료 안전성에 함께 영향.
- 추천 모델: GPT-6 Sol / Medium (Implementer·Reviewer). [모델 정책](../MODEL_POLICY.md) 참조.
- Review 예상: REQUIRED — 여러 관측 경로와 종료·파일 저장 동작 변경.
- Step 요청: 2026-10-27 사용자 요청.
- 구현 계획 승인: 사용자가 `monitor.sh`를 관측 로직의 단일 소유 파일로 만드는 구체적 계획과 [kill-agent-leak.sh](../../../kill-agent-leak.sh) 안전 수정·재사용, 기존 실행 스크립트의 호환 진입점 전환을 설명받은 뒤 “그럼 monitor 하나로 해도 괜찮다면 그렇게 해봐. 수정 시작”이라고 명시했다. 아래 일곱 파일의 승인된 방향 안에서만 구현한다.
- 변경 기준점: 현재 작업 트리에는 [README](../../../README.md), 기존 TASK/보고서, 준비·비교 도구의 미커밋 변경과 사용자 미추적 스크립트가 있다. 모두 보존한다.

## Execution State

- 현재 단계: 완료. 승인된 일곱 파일 구현, [REQUIRED 독립 리뷰](../reviews/REVIEW-TASK-006.md)의 Major-1/2·Minor-1 사용자 승인 수정, [수정 독립 재검토](../reviews/REVIEW-TASK-006-FIX.md) 완료. 재검토에서 새 Critical/Major/Minor 없음. 새 공통 경로의 메모리·CPU 종료/시간 만료·교착 시간 만료 사용자 실행을 확인했고 [최종 학습 절](../../study-note.md#task-006-공통-관측과-실행-후-안전-정리)을 현재 코드 기준으로 정리했다. 기존 2인자 호환과 실패·중단·수동 정리 경로는 정적 확인만으로 실행 미검증.
- 승인된 수정 계획: [monitor.sh](../../../monitor.sh)를 관측 로직의 단일 소유 파일로 확장한다. 새 3/4인자 호출은 `prepare-env.sh`로 앱을 실행하고, 같은 파일에 있는 기존 CSV 수집 로직을 백그라운드 호출하며 `top` 구간 CPU·앱 PID의 `ps -L` 스레드 표본을 수집한다. 기존 2인자 PID/CSV 호출의 결과 형식·앱 유지·파일 보호는 보존한다. [observe.sh](../../../observe.sh)와 기존 세 장애별 실행 스크립트는 새 3/4인자 호출에 전달하는 얇은 호환 진입점으로 바꾼다. 모든 새 공통 실행에서 `app.log`, 앱이 생성하는 `agent_app.log`, `monitor.csv`, `observation.txt`, `cpu-samples.csv`, `thread-observation.txt`를 사용한다. CPU 표본은 이번 실행 앱 PID만, 스레드 표본은 앱 PID만 기록한다. 전체 시스템 scope 파일은 새 실행에서 만들지 않는다. 설정만으로 장애를 확정하지 않고 로그·표본 신호와 미확인 항목을 요약한다.
- 승인된 종료 계획: [kill-agent-leak.sh](../../../kill-agent-leak.sh)의 자동 호출은 이번 실행 PID·시작 식별값만 받도록 고친다. 관측 종료 당시 상태를 먼저 요약한 뒤 동일성을 신호 직전에 재확인하여 TERM, 필요 시 동일 PID만 KILL하고 포트 상태를 확인한다. 준비 실패 등으로 동일성을 확인하지 못하면 신호를 생략하고 실패·수동 확인 대상을 명시한다. 명령행 부분 문자열 검색은 제거한다. 수동 무인자 호출은 현재 UID·이 저장소 바이너리 실제 경로가 정확히 일치하는 프로세스만 대상으로 삼고, 같은 바이너리의 다른 실행도 포함될 수 있음을 출력한다. `ps`/`ss` 실패는 성공으로 취급하지 않는다.
- 호환성 영향: 기존 세 실행 스크립트의 이름·3/4개 설정 인자 호출은 유지하지만 별도 수집 로직·과거 파일명과 앱을 남겨 두는 동작은 공통 증거·자동 정리로 바뀐다. `monitor.sh`의 새 설정값 호출도 앱을 관측 후 정리하고, 기존 2인자 PID/CSV 호출은 앱을 정리하지 않는다. [README](../../../README.md)에 차이를 명시하고 과거 증거·이력 문서는 보존한다.
- 승인 범위: [monitor.sh](../../../monitor.sh)가 3/4인자 공통 관측을 구현하고 2인자 PID/CSV 기존 동작을 보존한다. [observe.sh](../../../observe.sh)와 세 장애별 실행 스크립트는 thin wrapper, [kill-agent-leak.sh](../../../kill-agent-leak.sh)는 자동 호출에서 이번 실행 PID·시작 식별값만 검증·정리하고 수동 무인자는 현재 UID·정확한 앱 실행 파일 경로로 제한한다. [README](../../../README.md)는 새 사용법·동작 변경을 반영한다. 공통 산출물은 위 계획의 여섯 이름이며 과거 원본과 무관 파일은 보존한다.
- 구현 결과: `monitor.sh`에 기존 2인자 CSV 단독 호출과 신규 3/4인자 공통 관측을 두었다. `observe.sh`·세 장애별 스크립트는 호환 진입점, `kill-agent-leak.sh`는 자동 PID+시작 식별값 정리와 수동 정확 실행 파일 검색으로 바꾸었다. README 사용법을 갱신했다. Implementer는 셸 문법·diff 공백 정적 확인을 보고했고 앱 실행은 하지 않았다. PM은 `CPU Threshold Violated!` 요약 누락을 대조 중 발견해 승인 범위 안에서 보완을 회수했다.
- Review Decision: REQUIRED — 공통 증거 저장·기존 PID/CSV 호환·신호/종료 흐름 및 다중 스크립트 동작 변경. 새 GPT-6 Sol / Medium Reviewer의 [정적 리뷰](../reviews/REVIEW-TASK-006.md)는 Critical 없음, Major 2건·Minor 1건이다. 실제 실행 결과를 뜻하지 않는다.
- 승인된 리뷰 수정 계획: [monitor.sh](../../../monitor.sh)에서 top 표본 후 자연 종료와 PID 재사용을 구분해 확인 불가 표본을 별도 `identity_status`로 보존하고, 로그 검색의 일치·불일치·읽기 오류를 구분하며, 정리 후 PID 상태에 시작 식별값을 대조한다. [README](../../../README.md)에 새 CPU CSV 열과 해석 한계를 적는다. 기존 2인자 호출·종료 신호 정책·과거 원본은 유지한다. 승인 근거: 사용자 “수정”.
- 리뷰 수정 결과: Implementer는 [monitor.sh](../../../monitor.sh)와 [README](../../../README.md)만 변경하고 셸 문법·diff 공백 정적 확인을 보고했다. 종료 뒤 동일성 미확인 CPU 행, 로그 읽기 오류, 최종 PID 재사용 표시가 승인 범위대로 반영됐다. PM Review Decision: REQUIRED 재검토 완료; 새 finding이 없어 추가 리뷰 SKIP. 실제 앱 실행은 사용자 담당이다.
- 다음 행동: TASK-006 기능·학습 정리 마감. 기존 2인자 경로와 실패·중단·수동 정리 경로의 실행 검증은 별개로 미확인이다. 미션 CPU 급상승·Watchdog 근거는 [TASK-003](TASK-003.md)에서 계속 미확보다.

### 첫 공통 관측 사용자 실행: 128/40/false, 30초 한도

- 사용자가 `bash ./monitor.sh 128 40 false 30`과 셸 반환값 `0`을 전달했다. [실행 폴더](../../../runs/261027-215714_128_40_false-JX9kZg/)의 [app.log](../../../runs/261027-215714_128_40_false-JX9kZg/app.log), [agent_app.log](../../../runs/261027-215714_128_40_false-JX9kZg/agent_app.log), [monitor.csv](../../../runs/261027-215714_128_40_false-JX9kZg/monitor.csv), [CPU 표본](../../../runs/261027-215714_128_40_false-JX9kZg/cpu-samples.csv), [스레드 표본](../../../runs/261027-215714_128_40_false-JX9kZg/thread-observation.txt), [요약](../../../runs/261027-215714_128_40_false-JX9kZg/observation.txt)을 PM이 읽었다. `runs/`는 Git 제외 대상이다.
- 자식 PID 24966의 RSS는 첫 관제 18,272 KiB에서 마지막 실행 표본 146,292 KiB까지 증가했고, 21:57:32.448의 MemoryGuard는 Heap 150MB에서 128MB 한도 초과 및 자체 종료를 기록했다. CSV는 21:57:33 `EXITED`, 요약은 정리 전 자식 PID `absent`를 기록했다. 30초 한도를 채우기 전 앱이 종료된 정상 관측 경로이며 첫 RUNNING→EXITED의 17초는 표본 간격이다.
- `cpu-samples.csv`는 앱/launcher 두 PID만 14개 구간에 기록했고 앱 `%CPU`는 이 실행에서 최대 4.0%다. 스레드 표본은 시작·약 15초 시점의 앱 PID 행만 담았다. 요약은 MemoryGuard 신호와 CPU 임계치·Watchdog·WAITING/BLOCKED 문구 부재를 구분한다. 이 실행은 CPU 과점유·교착 증거가 아니다.
- 정리 결과는 `Tool cleanup status: 0`, 두 PID 최종 absent, 포트 15034 해제다. PM의 별도 `ss` 조회도 LISTEN 행이 없었다. 터미널의 `24961 Killed`는 launcher 작업에 대한 Bash 알림이며 `app.log`의 자식 MemoryGuard 자체 종료와 다른 대상이다. 정리 도구의 KILL 단계 문구는 요약에 없어 그 알림의 신호 발신자를 단정하지 않는다.
- 사용자 검증 범위는 이번 128/40/false 자연 종료 한 경로다. CPU·교착 설정의 공통 형식/자동 정리, 기존 2인자 PID/CSV 호출, 실패·중단·수동 정리 경로는 미검증으로 유지한다.

### CPU 설정 공통 관측 사용자 실행: 512/80/false, 60초 한도

- 사용자가 `bash ./monitor.sh 512 80 false 60`과 셸 종료값 `0`을 전달했다. [실행 폴더](../../../runs/261027-220215_512_80_false-LYxfY1/)의 [app.log](../../../runs/261027-220215_512_80_false-LYxfY1/app.log), [agent_app.log](../../../runs/261027-220215_512_80_false-LYxfY1/agent_app.log), [monitor.csv](../../../runs/261027-220215_512_80_false-LYxfY1/monitor.csv), [CPU 표본](../../../runs/261027-220215_512_80_false-LYxfY1/cpu-samples.csv), [스레드 표본](../../../runs/261027-220215_512_80_false-LYxfY1/thread-observation.txt), [요약](../../../runs/261027-220215_512_80_false-LYxfY1/observation.txt)을 PM이 읽었다. `runs/`는 Git 제외 대상이다.
- 자식 PID 25496의 앱 내부 `CpuWorker Current Load`는 22:02:18의 5.00%에서 22:02:36의 51.89%까지 증가했고 22:02:36.930에 `CPU Threshold Violated!`를 기록했다. CSV의 첫 `RUNNING` 22:02:16부터 `EXITED` 22:02:37까지는 21초 관측 간격이다. 요약의 정리 전 앱 상태는 `absent`라서 새 도구 정리 때문에 자식이 종료된 것으로 보지 않는다.
- `cpu-samples.csv`의 확인된 앱 PID 구간 표본 17개는 최대 4.0%이며 `TIME+`는 0:00.05→0:00.20이다. `monitor.csv`의 종료 직전 수명 평균 `%CPU`는 1.0%, RSS는 약 18,220 KiB였다. 앱 내부 Load와 OS `%CPU`는 같은 지표로 환산하지 않는다. 로그에는 Watchdog·SIGTERM 명시가 없으므로 OS CPU 과점유와 Watchdog 보호 종료 근거는 여전히 미확보다.
- 정리 결과는 status 0, 두 PID 최종 absent, 포트 15034 해제다. PM 별도 `ss` 조회도 LISTEN 행이 없었다. 반환값 0은 증거 수집·정리의 성공이며 CPU 장애 입증이 아니다. 60초 한도 전에 앱이 사라졌으므로 이번 실행은 시간 만료 뒤 살아 있는 앱의 자동 정리 경로를 검증하지 않는다.

### CPU 40% 공통 관측 사용자 실행: 512/40/false, 60초 한도

- 사용자가 `bash ./monitor.sh 512 40 false 60`과 셸 종료값 `0`을 전달했다. [실행 폴더](../../../runs/261027-221144_512_40_false-V0VJm5/)의 [app.log](../../../runs/261027-221144_512_40_false-V0VJm5/app.log), [agent_app.log](../../../runs/261027-221144_512_40_false-V0VJm5/agent_app.log), [monitor.csv](../../../runs/261027-221144_512_40_false-V0VJm5/monitor.csv), [CPU 표본](../../../runs/261027-221144_512_40_false-V0VJm5/cpu-samples.csv), [스레드 표본](../../../runs/261027-221144_512_40_false-V0VJm5/thread-observation.txt), [요약](../../../runs/261027-221144_512_40_false-V0VJm5/observation.txt)을 PM이 읽었다. `runs/`는 Git 제외 대상이다.
- 앱은 22:11:46 `Healthy System Monitoring`과 A/B/C 완료를 기록한 후 MemoryWorker와 CpuWorker를 실행했다. 내부 `Current Load`는 40.00% 피크에서 cooldown해 5.00%로 돌아왔고 22:12:43에는 13.67%였다. MemoryWorker Heap은 25→475MB, OS RSS는 첫 18,336→마지막 504,588 KiB로 증가했다. 이 60초 안에는 MemoryGuard·CPU 임계치 위반·Watchdog·WAITING/BLOCKED 문구가 없다.
- 자식 PID 26088의 확인된 `top` 구간 표본 51개는 최대 7.0%, 누적 CPU 시간 0:00.05→0:01.17이다. 22:12:45 관측 종료 때 상태 `SNl+`, 마지막 CSV는 `RUNNING`이었다. CSV 관제 종료 status 143은 이 스크립트가 살아 있는 앱의 관제 수집기만 TERM한 결과이며 명령 반환값 0과 일치한다. 이는 앱 자연 종료나 보호 종료가 아니다.
- 그 뒤 도구 정리 status 0, 양 PID 최종 absent, 포트 15034 해제를 확인했다. PM 별도 `ss` 조회도 LISTEN 행이 없다. 60초는 앱의 생존 하한일 뿐 자연 종료 시간은 아니다.
- 비교 대상인 위 512/80/false는 `CpuWorker` 임계치 위반 뒤 자식이 관측 중 사라졌고 이 40% 실행은 관측 끝까지 살아 있었다. 두 실행은 CPU 설정만 달리했지만 앱이 선택한 작업 경로도 달라, 생존 차이를 CPU 정책의 단독 효과로 설명하지 않는다. 두 자식의 OS `top` 사용률은 낮고 Watchdog 종료 로그도 없으므로 CPU 필수 증거 미확보 상태는 유지한다.

### 교착 설정 공통 관측 사용자 실행: 400/40/true, 60초 한도

- 사용자가 `bash ./monitor.sh 400 40 true 60`과 셸 종료값 `0`을 전달했다. [실행 폴더](../../../runs/261027-221930_400_40_true-wMYexd/)의 [app.log](../../../runs/261027-221930_400_40_true-wMYexd/app.log), [agent_app.log](../../../runs/261027-221930_400_40_true-wMYexd/agent_app.log), [monitor.csv](../../../runs/261027-221930_400_40_true-wMYexd/monitor.csv), [CPU 표본](../../../runs/261027-221930_400_40_true-wMYexd/cpu-samples.csv), [스레드 표본](../../../runs/261027-221930_400_40_true-wMYexd/thread-observation.txt), [요약](../../../runs/261027-221930_400_40_true-wMYexd/observation.txt)을 PM이 읽었다. `runs/`는 Git 제외 대상이다.
- 앱 로그는 Worker-Thread-1이 Shared_Memory_A를 점유한 채 Socket_Pool_B를, Worker-Thread-2가 Socket_Pool_B를 점유한 채 Shared_Memory_A를 기다린다고 22:19:40.159에 끝난다. 22:20:32 관측 종료까지 약 52초간 후속 앱 로그가 없다. 이 순환 대기는 앱 로그로 추론하고 `futex_wait`만으로 락 소유 관계를 단정하지 않는다.
- 자식 PID 27204의 CSV는 끝까지 `RUNNING`이며 22:19:40~22:20:32의 53개 RUNNING 표본 RSS가 모두 18,408 KiB다. 같은 PID의 `top` 구간 표본 52개는 최대 0.0%, 누적 CPU 시간은 0:00.05에서 변하지 않는다. `ps -L`의 15·30·45초 표본에서 세 스레드는 계속 `futex_wait`다. CSV `%CPU`가 0.5→0.0%로 내려가는 것은 수명 평균이며 구간 CPU 정체는 별도 top으로 확인한다.
- 요약의 정리 전 자식 상태는 `SNl+`, 마지막 CSV는 `RUNNING`, 관제 수집기 status 143이다. 이후 도구 정리 status 0, 양 PID 최종 absent, 포트 15034 해제를 기록했다. PM 별도 `ss` 조회도 LISTEN 행이 없다. 따라서 이번 실행의 앱 종료는 관측 이후 도구 정리이며 교착 상태가 자연 해소됐다는 뜻이 아니다.
- 이번 한 실행은 기존 [TASK-004](TASK-004.md)의 true/false 비교를 대체하지 않는다. 공통 도구가 교착 증거를 수집하고 관측 후 정리하는 경로의 사용자 검증이다. 기존 2인자 관제, 중단·실패, 수동 무인자 정리는 아직 실행 미검증이다.

## Requirements

- [MISSION §2·§4](../MISSION.md)의 메모리 RSS 증가·보호 종료, 대상 프로세스 CPU 변화·보호 종료, PID 생존과 스레드 정체의 증거를 각각 수집할 수 있게 한다. 필수 증거가 없는 실행은 성공적인 장애 입증으로 표시하지 않는다.
- [REQ-002~004](../REQUIREMENTS.md)에 필요한 비교 실행에서 세 환경변수만 바꾸고 같은 관측 명령을 쓸 수 있게 한다.

## Constraints

- [monitor.sh](../../../monitor.sh)를 실제 관측 명령으로 사용한다. 기존 2인자 PID/CSV 단독 수집 호출은 유지한다. 바이너리와 과거 `runs/` 증거 내용은 변경하지 않는다.
- 모든 실행에서 공통 앱 로그·관제 CSV·짧은 요약 텍스트를 얻고, 추가 표본은 미션 근거에 필요한 앱 PID·스레드로 제한한다. 길고 관련 없는 전체 시스템 행을 남기지 않는다.
- 실행 결과를 설정값만으로 미리 분류하거나 `CpuWorker` 내부 Load를 OS `%CPU`로 환산하지 않는다. 관측 종료와 앱 자연 종료·보호 종료·도구에 의한 정리를 구분한다.
- 자동 정리는 이번 실행에서 확인한 프로세스만 대상으로 하고, 포트를 사용하는 다른 프로세스를 종료하지 않는다. 정리 실패와 부트/수집 실패는 성공처럼 표시하지 않는다. 기존 사용자 스크립트와 미커밋 변경을 보존한다.
- 실제 앱 실행·테스트는 사용자 담당이다.

## Scope

- 승인된 수정 파일은 [monitor.sh](../../../monitor.sh), [observe.sh](../../../observe.sh), [observe-memory.sh](../../../observe-memory.sh), [run-cpu-observation.sh](../../../run-cpu-observation.sh), [run-deadlock-observation.sh](../../../run-deadlock-observation.sh), [kill-agent-leak.sh](../../../kill-agent-leak.sh), [README.md](../../../README.md)다.
- [prepare-env.sh](../../../prepare-env.sh), [run-memory-comparison.sh](../../../run-memory-comparison.sh), 사용자 [memory-test.sh](../../../memory-test.sh), 과거 `runs/` 증거는 변경하지 않는다.

## Out of Scope

- 과거 실행 증거의 삭제·재작성, 제공 바이너리 내부 분석, 없는 Watchdog/OS CPU spike 근거를 만들어내기, 다른 계정 또는 다른 실행의 프로세스 일괄 종료, 미션과 무관한 프로세스/포트 정리 도구 확장.

## Acceptance Criteria

- [x] `bash ./monitor.sh MEMORY_LIMIT CPU_MAX_OCCUPY MULTI_THREAD_ENABLE [SECONDS]`로 시작하고, 사용자가 장애 종류를 명령 인자로 지정하지 않아도 된다.
- [x] 기존 `bash ./monitor.sh PID NEW_LOG_FILE`의 CSV 단독 관제·앱 유지 동작은 보존한다. 기존 경로의 실제 재실행은 미검증이며 정적 코드·독립 리뷰로 확인했다.
- [x] 세 설정 조합 모두 같은 이름의 앱 로그·관제 CSV·간결한 결과 요약을 생성한다. 장애별 추가 근거는 필요한 앱 PID/스레드만 저장한다.
- [x] 결과 요약이 관측된 사건과 판정 근거·불확실성을 구분하며, 다중·불명확 신호를 단정하지 않는다.
- [x] CPU 파일은 전체 시스템 프로세스 반복 기록을 없애되 대상 PID의 구간 CPU 값·부모 자식 관계·첫 프레임 제외 여부를 확인할 수 있다.
- [x] `monitor.sh`가 실제로 RSS/CPU 수명 평균·상태를 기록한다.
- [x] 관측 종료 당시의 생존·종료 상태를 저장한 뒤, 이번 실행 앱만 정리하고 포트 해제를 확인한다. 자동 정리로 인한 종료를 앱의 자연 종료나 보호 종료로 보고하지 않는다.
- [x] 부분 실패와 사용자 중단의 증거·종료 상태를 구분하고 원본을 덮어쓰지 않는다. 실패·중단 실제 실행은 미검증이며 정적 코드·독립 리뷰로 확인했다.
- [x] Implementer 정적 self-check, REQUIRED 독립 리뷰, 사용자 실행 검증을 거친다.

## Relevant Files

- [observe.sh](../../../observe.sh), [observe-memory.sh](../../../observe-memory.sh), [run-cpu-observation.sh](../../../run-cpu-observation.sh), [run-deadlock-observation.sh](../../../run-deadlock-observation.sh), [kill-agent-leak.sh](../../../kill-agent-leak.sh), [prepare-env.sh](../../../prepare-env.sh), [monitor.sh](../../../monitor.sh), [README.md](../../../README.md).

## Implementation Notes

- 기존 `app.log`는 앱 표준출력·표준에러이고 `agent_app.log`는 앱이 직접 쓰는 파일이다. `monitor.csv`는 공통 도구 출력이다. 추가 파일 형식·이름은 계획 단계에서 현재 구조와 호환성을 살펴 최소로 제안한다.

## Learning Deliverable

- 구현·리뷰·사용자 검증 완료 후 [study-note.md](../../study-note.md)에 TASK-006 절을 최종 코드 기준으로 정리한다.
