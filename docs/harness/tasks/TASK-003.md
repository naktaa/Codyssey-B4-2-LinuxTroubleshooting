# TASK-003: CPU 과점유 관측과 설정 전후 비교

## Goal

대상 프로세스의 CPU 급상승과 Watchdog 보호 종료를 증거로 확인하고 CPU_MAX_OCCUPY 변경 전후 종료 여부 또는 생존 시간을 비교해 CPU 보고서 1건을 작성한다.

## Context

- 사용자 “그럼 하지 말고 넘어가자. 다음 단계”로 TASK-002 실패 경로 실행 검증 생략 및 다음 CPU 단계 진행을 요청했다(2026-10-09).
- 난이도 MEDIUM, Implementer GPT-6 Sol / Medium. 기존 도구 재사용과 관측 조건·로그 해석이 필요하다.
- Review 예상 RECOMMENDED: 증거와 해석 검토. 실행·저장 기능 변경이 추가되면 실제 범위에 따라 REQUIRED로 재판정한다.
- 구현 계획 승인: 2026-10-13 사용자가 아래 기존 실행 도구 인자화 계획을 승인했다.
- 시작 HEAD: `e4655e3`. 시작 시 작업 트리 clean. 이후 PM 상태 기록 변경은 이번 인계에 포함한다.

## Execution State

- 현재 단계: 현 증거 기준 CPU 보고서 작성·사용자 확인 완료. CPU 관측 도구 REQUIRED 재검토와 기존 CPU 보고서 RECOMMENDED 독립 재검토 완료. 2026-10-28 추가 앱 로그 근거를 보강했으나 CPU 과점유·Watchdog 필수 증거는 미완료다.
- 승인 범위: [prepare-env.sh](../../../prepare-env.sh)의 메모리·CPU·멀티스레드 3개 위치 인자 지원, [메모리 비교 스크립트](../../../run-memory-comparison.sh)의 명시 인자 호출, [README](../../../README.md)의 사용법 반영. 무인자 환경변수·기본값 방식은 유지한다.
- 위임: 이전 `gpt-6-sol` 호출은 아래 이력으로 보존한다. 이번 계획은 새 Implementer `gpt-6.1-sol` / `medium`, `fork_turns="none"`으로 회수했다. 도구가 요청 설정을 수락했으며 실제 하위 실행 모델 메타데이터는 별도 확인하지 않았다.
- 결과 위치: 이 TASK에 회수한 계획을 기록한다.
- 다음 행동: 사용자가 현재 증거 기준 [CPU 보고서](../../reports/cpu.md) 마무리를 요청했다. 추가 `top` 실험은 반복하지 않는다. 앱 `Current Load` 정의와 종료 주체가 확인되지 않아 OS CPU 과점유·Watchdog 근거를 완료로 처리하지 않은 채, 다음 제출 준비 단계에서 이 한계를 유지한다.

### 2026-10-28 앱 내부 임계치 근거 보강

- 사용자 요청에 따라 새 실행 없이 기존 512/80/false와 400/90/false 원본의 앱 `Current Load` 약 50~52% → `CPU Threshold Violated!` → 다음 관제 표본 `EXITED` 순서를 [CPU 보고서](../../reports/cpu.md)에 보강했다. 90% 실행은 메모리 설정이 달라 80%와 동일 조건 효과 비교가 아니다.
- 사용자 판단에 따라 `top` 반복 실험은 중단한다. 기존 OS 표본은 보존하고, 앱 내부 시나리오·보호 분기는 추론으로 적는다. 고정 50% 판정식, Watchdog 주체·종료 신호 및 OS CPU 급상승은 입증하지 못했다.
- Review Decision: SKIP — 이전 독립 재검토의 해석 범위 안에서 기존 원본 두 건을 국소 추가했고 PM이 링크·설정·시각·CSV 상태와 diff를 대조했다. 기능 source·원본 변경이나 AI 실행·테스트는 없다. REQ-003과 TASK 마감 학습 정리는 대기한다.

### 2026-10-27 40% 비교 관측·보고서 반영

- 사용자가 `ss -ltn '( sport = :15034 )'` 출력에서 리스너가 없는 상태를 확인한 뒤 `bash ./run-cpu-observation.sh 512 40 false`를 실행하고 반환값 `0`을 전달했다. [앱 로그](../../../runs/261027-161341_512_40_false-binP1r/app.log), [앱 자체 로그](../../../runs/261027-161341_512_40_false-binP1r/agent_app.log), [관제 CSV](../../../runs/261027-161341_512_40_false-binP1r/monitor.csv), [프로세스 관계표](../../../runs/261027-161341_512_40_false-binP1r/process-scope.log), [top CSV](../../../runs/261027-161341_512_40_false-binP1r/top-scope.csv)를 읽기 전용 대조했다.
- 부트 성공·512/40/false 확인. 앱은 `Healthy System Monitoring`을 선택했고 작업 A/B/C를 완료했다. 내부 `Current Load`는 40%에 도달한 뒤 cooldown을 시작해 5%로 낮아졌다. launcher 5479·자식 5484는 61개 ps/top 프레임(16:13:43~16:14:43) 모두에서 확인됐고, 관제 60행(16:13:42~16:14:42)은 모두 `RUNNING`이다. 관측 종료 시 사용자가 제시한 ps에도 둘 다 살아 있었다. 이후 생존 시간·종료 이유는 이번 관측으로 측정하지 않았다.
- 자식의 top 순간 CPU 최대 8%, 누적 CPU 시간 0:00.05→0:01.26(60초에 1.21 CPU초)이며 launcher의 누적 시간은 0:00.06으로 일정하다. 프레임 표본의 앱 프로세스는 두 PID뿐이다. 관제 RSS는 18,340→505,048KiB까지 증가했다. 첫 메모리 정리 로그 16:14:45.944는 마지막 top·CSV 표본 뒤이므로 60초 관측 안의 결과로 세지 않는다.
- 80%는 첫 `RUNNING` 후 30초에 `EXITED`가 관측됐고 40%는 60초 끝에도 살아 있었다. 메모리·멀티스레드 입력은 같지만 앱 경로가 달라 40% 설정의 OS CPU 완화 효과나 동일 작업의 생존 시간 개선으로 단정하지 않는다. 두 실행 모두 OS CPU 급상승·Watchdog 조치 주체를 입증하지 못한다. 설정 전후 상태 비교만 확보했다.
- 이전 대화에서 제시한 한 파일 계획에 따라 Implementer `gpt-6-sol` / `medium`, `fork_turns="none"`이 [CPU 보고서](../../reports/cpu.md)만 갱신했다. PM은 실제 diff·원본 시각·수치와 관측 구간 밖 기록의 분리를 대조했고 `git diff --check`를 확인했다. PM/Implementer의 앱·스크립트·테스트 실행 없음. Review Decision RECOMMENDED — 사용자 “일단 진행해봐”로 새 Reviewer `gpt-6-sol` / `medium`, `fork_turns="none"`의 [독립 재검토](../reviews/REVIEW-TASK-003-CPU-REPORT.md#2026-10-27-비교-추가-독립-재검토)를 회수했다. Critical/Major/Minor 없음, PM Disposition 완료. 재검토 후 보고서 변경이 없어 추가 리뷰 SKIP. 지정 설정 수락과 실제 실행 모델 메타데이터 검증은 구분한다. REQ-003·최종 학습 정리는 미완료다.

### 2026-10-27 첫 CPU 범위 관측 사용자 검증

- 사용자가 `bash ./run-cpu-observation.sh 512 80 false`를 실행하고 반환값 `0`을 전달했다. [앱 로그](../../../runs/261027-155944_512_80_false-5osiuy/app.log), [앱 자체 로그](../../../runs/261027-155944_512_80_false-5osiuy/agent_app.log), [관제 CSV](../../../runs/261027-155944_512_80_false-5osiuy/monitor.csv), [프로세스 관계표](../../../runs/261027-155944_512_80_false-5osiuy/process-scope.log), [top CSV](../../../runs/261027-155944_512_80_false-5osiuy/top-scope.csv)를 PM이 읽기 전용으로 대조했다. 61개 top·ps 프레임이 15:59:45~16:00:45에 기록됐다.
- 부트 성공·설정 512/80/false 확인. 앱 `Current Load` 5.00→53.08%, 16:00:14.658 `CPU Threshold Violated!`, 자식 4283은 16:00:15 관제에서 `EXITED`다. 앱 프로세스는 프레임 30(16:00:14)까지 존재하고 31(16:00:15)부터 없으며 마지막 출력의 빈 ps 표와 일치한다. 관측 스크립트는 앱 종료 명령을 보내지 않았다. 종료 신호·Watchdog 주체와 포트 해제는 이번 로그만으로 확정하지 않는다.
- ps 관계표의 프레임 1~30에서 확인한 앱 프로세스는 launcher 4278과 직접 자식 4283뿐이며 추가 후손은 표본에 없다. top은 두 PID 각각 30행을 저장했다. 첫 프레임을 제외한 부모 CPU는 전부 0.0%, 누적 시간은 0:00.08로 일정하다. 자식의 최고 순간 CPU는 5.0%(16:00:11), 누적 시간은 0:00.04→0:00.32로 약 29초 동안 0.28 CPU초 증가했다. 자식의 관제 CPU는 실행 기간 0.7~4.0%의 시작 이후 평균값이며 급상승 증거가 아니다. 1초 표본 사이의 매우 짧은 후손은 배제할 수 없다.
- 반환값 `0`은 수집 완료를 뜻한다. 앱 내부 지표의 계산식과 80% 설정에서 53.08%에 임계치 위반이 나온 이유는 미확인이다. 프로세스 OS CPU 과점유·Watchdog 보호 조치 입증과 설정 전후 검증은 여전히 미완료다. Review Decision SKIP — 읽기 전용 원본 대조·상태 기록이며 source 변경 없음. PM은 앱·스크립트·테스트를 실행하지 않았다.

### 2026-10-27 관측 도구 구현·리뷰 및 수정 계획

- 수정 승인: 사용자 “수정 시작”으로 아래 Major-1/2 구체적 보완 계획 및 관측 스크립트·README 두 파일 수정을 승인했다. 새 기능·사용자 top 설정 변경·범용 파서·기존 도구 수정은 범위에 포함하지 않는다. 사용자 작업 중인 test*.c·.gitignore·.vscode 등은 보존한다.
- 수정 결과: Implementer `gpt-6.1-sol` / `medium`이 두 파일만 변경했다. 프레임별 ps 부모 관계에서 앱 관련 PID를 찾고 다음 헤더·마지막 EOF에서 top 출현을 검사한다. 첫 프레임 이후 launcher/app의 유효 표본을 각각 요구한다. 필수 열 앞의 허용 목록·CPU/TIME+ 형식을 확인한 뒤 저장하며 뒤쪽 원문 필드는 저장하지 않는다. 지원 레이아웃과 시점 차이·필터 미해제 한계를 README에 명시했다.
- Review Decision REQUIRED로 새 Reviewer `gpt-6.1-sol` / `medium`, `fork_turns="none"`의 [변경 범위 재검토](../reviews/REVIEW-TASK-003-CPU-OBSERVATION.md)를 회수했다. Major-1/2 정적 해결·새 Critical/Major/Minor 없음. PM이 수정 전 사본 diff·최종 파일을 대조했다. 지정 설정 수락과 실제 실행 메타데이터 검증은 구분한다. 추가 리뷰 SKIP(재검토 후 source 변경 없음).
- 앱·스크립트·문법 검사·테스트는 실행하지 않았다. 정상 수집·사용자 top 필터/열 배치·시간 만료·신호·쓰기 실패는 사용자 실행 검증 대기다. 학습 정리는 TASK 마감 시 수행한다.

- 구현: [run-cpu-observation.sh](../../../run-cpu-observation.sh)와 [README](../../../README.md) CPU 절만 Implementer `gpt-6.1-sol` / `medium`이 변경했다. Bash coproc로 top을 직접 자식으로 두고 PID·읽기 FD를 보존하며 선택 열 CSV와 전체 ps 관계표를 저장한다. PM 기존 상태 변경과 사용자 파일은 보존했다. source 정적 self-check·PM 실제 파일 대조 완료, 앱·스크립트·테스트 실행 없음.
- Review Decision REQUIRED: 증거 저장·수집 자식 수명 처리. 새 Reviewer `gpt-6.1-sol` / `medium`, `fork_turns="none"`의 [독립 리뷰](../reviews/REVIEW-TASK-003-CPU-OBSERVATION.md)에서 Major-1(필터로 앱 PID 누락 가능), Major-2(선행 ENVIRON 등으로 열 오염 가능)를 회수했다. Critical/Minor 없음. 두 finding ACCEPT, 아직 미수정.
- 보완 예정 파일은 관측 스크립트·README 두 개다. 프레임별 ps 관계표의 launcher·app·연결 후손 PID가 top에 나타나는지 검사하고 누락이나 유효 앱 표본 부재를 불완전으로 판정한다. 사용자 필터 완전 해제를 보장하지 않으며 시점 차이·표본 사이 후손 생존 한계를 명시한다.
- 마지막 필수 열까지 기본 단일 토큰 필드(PID USER PR NI VIRT RES SHR S %CPU %MEM TIME+)만 허용하고 선행/중간 미지원 필드는 저장 전 실패 처리한다. CPU 숫자·TIME+ 지원 형식도 확인한다. 필수 열 뒤의 데이터는 저장하지 않는다. 사용자 설정 파일 변경·범용 rc 파서·공통 모듈·신규 의존성은 추가하지 않는다.
- 위 수정은 사용자 승인 후 반영됐으며 결과는 이 절의 수정·재검토 기록을 따른다. 정적 검토 완료를 실제 실행 성공이나 CPU 필수 증거 확보로 간주하지 않는다.

### 2026-10-27 CPU 관측 범위 보완 계획

- 구현 승인: 사용자 “구현 시작”으로 앞서 제시한 신규 `run-cpu-observation.sh`와 README 사용법 두 파일 계획 승인. 기존 준비/관제/Deadlock 도구·바이너리·원본·보고서는 변경하지 않는다. 승인된 저장 범위·입력·실패 처리·앱 유지 정책을 아래 계획대로 구현하고 실제 실행은 사용자에게 맡긴다.

- 사용자 “다음 작업”으로 재개. 기준 HEAD `d0fa83a`, 시작 작업 트리 clean. 제공 문서·파일에 Current Load 계산식이 없으며 바이너리 내부는 분석하지 않았다. 준비 도구는 시작 시 직접 자식 하나를 식별하지만 이후 후손 전체를 추적하지 않는다. 기존 관측 PID가 틀렸다고 결론 내리지 않는다.
- 목적: launcher·추가 후손을 관측하지 않아 CPU 사용을 놓쳤는지 한 차례 검토한다. 전체 프로세스 관계표에서 앱에 연결되는 PID를 식별한 뒤 해당 CPU 표본만 앱 근거로 사용한다. 시스템 전체 부하를 앱 CPU로 대체하지 않는다.
- 사용자 반복 입력 최소화 선호에 따른 신규 예정 `run-cpu-observation.sh`와 [README](../../../README.md) 두 파일 계획이다. 세 설정(메모리/CPU/멀티스레드)과 선택 관측 초(기본60, 정수15~300)를 받으며 기존 준비·CSV 관제를 재사용한다. 기존 Deadlock 도구·바이너리·보고서·학습 노트는 변경하지 않는다.
- 저장 계획: 고유 run_dir에 기존 앱 로그·monitor.csv와 함께 1초 간격 전체 ps 관계표(PID·PPID·시작 시각·누적 CPU·상태·comm, args 제외), top에서 추출한 시각·PID·%CPU·TIME+ 표를 저장한다. top은 LC_ALL=C 헤더로 열을 식별하고 필수 열 누락 시 실패를 알린다. COMMAND·명령 인자는 저장하지 않으며 사용자 top 설정을 변경하지 않는다. 첫 top 표본은 구간 비교에서 제외한다.
- 시간 만료·실패·중단 시 자신이 시작한 수집 자식만 정리·회수하고 앱은 유지한다. 새 파일은 noclobber로 기존 증거를 보호하고 실패를 성공으로 표시하지 않는다. 앱 종료·부트·프로세스 상태와 원본 경로를 출력한다.
- 첫 후보는 기존 CPU 설정 512/80/false다. 모든 앱 관련 PID의 실제 CPU도 낮고 지표 정의가 없으면 OS 급상승 미확보로 기록하고 제공자에게 계산식·측정 대상·부하 발생 조건·보호 종료 정책을 확인할 경계다. 표본 사이의 짧은 후손 생존은 놓칠 수 있으며 지표가 모의값이라고 단정하지 않는다. 추가 부하를 인위적으로 만들어 증거를 대체하지 않는다.
- 최초 계획 단계의 Review Decision은 SKIP(읽기 전용 계획·상태 기록)이었다. 이후 구현 승인·REQUIRED 리뷰·수정 재검토는 위 최신 기록을 따른다.

### 2026-10-26 CPU 보고서 초안 작성

- 후속 사용자 “진행”으로 RECOMMENDED 독립 리뷰 실시. 새 Reviewer `gpt-6-sol` / `medium`, `fork_turns="none"`의 [리뷰 결과](../reviews/REVIEW-TASK-003-CPU-REPORT.md)는 Critical/Major/Minor 없음. PM 원본·결과 대조 및 Disposition 완료. 추가 리뷰 SKIP(보고서 변경 없음). 실제 실행 모델 메타데이터는 별도 확인하지 않았다.

- 사용자 “더 바꿔서 테스트할게 없으면 아까 기록한다는거 마무리”로 앞서 제시한 신규 CPU 보고서 한 파일 작성 계획을 승인했다. Implementer `gpt-6-sol` / `medium`에 승인 범위를 전달해 작성 결과를 회수했다. 직전 설명 위임은 모델 capacity 오류로 실패했고, 이번 사용자 요청 후 같은 에이전트·모델을 재호출했다. 임의 모델 대체 없음.
- [CPU 보고서](../../reports/cpu.md)의 네 필수 절, 원본 발췌와 PID·시각·표본 수·누적 CPU 시간, 간접 근거인 과거 40% 수동 종료 기록을 정적으로 대조했다. 실제 앱 실행·테스트 및 source 수정 없음.
- 사용자 제공 환경 출력: Linux 논리 CPU 6개(0~5), x86_64, KVM. 새 top에서 I 입력 시 Off이므로 현재 시작 모드는 Irix On. 과거 수집 모드는 소급 확정하지 않으며 OrbStack 환경이라고 단정하지 않는다. 표시 모드 전환은 수치를 바꾸지만 실제 CPU 사용량을 바꾸지 않는다.
- Review Decision: RECOMMENDED — 평가 핵심 보고서의 증거·인과 해석 검토. 추천 Reviewer `gpt-6-sol` / `medium`. 사용자 진행/생략 결정 전 독립 리뷰 미실시. CPU 필수 증거 부족과 TASK 미완료 유지, 최종 학습 정리는 보류한다.

### 2026-10-26 보완 관측 계획

- 사용자 보완 실행 결과 확인: `runs/261026-160154_512_80_false-2PYjC0` 원본이 현재 작업 공간에 존재하며 직접 대조했다. 512/80/false 부트 통과, 자식 PID 5286. 실행 기록 16:01:54 → CSV EXITED 16:02:28은 약 34초, 첫 CSV RUNNING 16:02:01 → EXITED는 27초다. 시작과 관제 사이 약 7초는 CSV 관측 밖이다.
- app.log는 16:02:27.864 Current Load 약 50.42%에서 CPU Threshold Violated를 기록했다. top의 대상 PID 표본 26개는 0~5%이며 OS CPU 과점유 증거로 단정하지 않는다. Watchdog/SIGTERM 명시는 없다. 사용자 셸의 Terminated는 종료 관측 근거이나 신호 발신자·정책을 입증하지 않는다. top은 앱 종료 후에도 빈 대상 목록으로 16:02:59까지 기록했다.
- Review Decision: SKIP — 사용자 원본 읽기 및 상태 기록만 수행. CPU 필수 증거 미충족 유지. 다음은 관측 지표 불일치·종료 근거의 한계를 정리한 보고서 계획 검토이며, 동일 조건 반복으로 재현 성공을 추정하지 않는다.

- 사용자 “다음 단계 진행”으로 읽기 전용 계획을 진행했다. 기준 HEAD `64dc487`, 시작 작업 트리 clean.
- Implementer `gpt-6-sol` / `medium`, `fork_turns="none"`으로 계획을 회수했다. 도구가 지정 설정을 수락했으며 실제 실행 모델 메타데이터는 별도 확인하지 않았다.
- source 수정 없이 기존 준비 도구로 512/80/false 실행 후 같은 자식 PID에 top 배치 표본(1초 간격, 60회)과 monitor CSV를 함께 수집한다. top 로그는 새 run_dir에 noclobber로 저장한다. 60초 표본 종료는 앱 종료를 의미하지 않는다.
- 현재 작업 공간에 runs 원본이 없어 이전 수치는 저장된 기록 기준이다. 사용자 실행 결과로 OS CPU와 앱 지표를 구분하고 Watchdog 종료 근거를 확인한 뒤 비교·보고서 계획을 정한다. 필수 증거 확보를 보장하지 않는다.
- Review Decision: SKIP — 기존 도구 실행 안내만 회수. 기존 인자화 REQUIRED 리뷰 완료 유지. source 수정·실행 테스트 없음. 보고서 작성 계획은 아직 승인되지 않았다.

## 2026-10-13 인자화 승인 및 첫 관측

- 승인 근거: 사용자 “모든 필수기능을 수행할 때 저 인자 간편하게 설정 가능하다면 그렇게 수정.” 앞서 제시한 세 파일 수정 계획에 대한 승인이다.
- 인터페이스: `source ./prepare-env.sh 512 40 false`. 인자가 있으면 정확히 3개를 받아 기존 범위 검증을 적용하고, 무인자이면 기존 환경변수·기본값을 사용한다. 인자가 현재 셸의 이전 실험 설정보다 우선한다.
- 메모리 비교 함수의 위치 인자가 무인자 source에 상속되는 문제를 막기 위해 해당 호출에서 세 설정을 명시한다. 관제 도구·바이너리·기존 원본·학습 본문 변경, 신규 스크립트와 dependency 추가는 제외한다.
- 메모리·CPU·Deadlock 필수 비교에 필요한 세 환경변수 설정을 지원한다. 설정 가능 여부와 각 장애의 재현·필수 증거 확보는 별개다.
- 구현 위임: Implementer `gpt-6-sol` / `medium`, `/root/cpu_instructions`. 기준점은 HEAD `346afbb`, 승인 기록 전 작업 트리 clean. 실제 실행·테스트는 사용자 담당.
- 첫 CPU 관측: `runs/run-2026-10-13_16-29-50-Ni7K0x`의 부트 설정은 512/80/false, PID 4910. CSV 첫 RUNNING 16:29:51 → EXITED 16:30:28(37초). 앱 Current Load 5.00→50.58% 및 CPU Threshold Violated 기록. 사용자 top 캡처 16:30:12의 3.0%, 사용자 관찰 약 5%. Watchdog·SIGTERM 명시와 OS CPU 과점유 근거는 미확인이다.
- 다음 CPU 비교 후보는 512/40/false다. 별도 언급이 없으면 실행 시각이 최신인 runs 디렉터리를 찾아 실제 설정·PID와 대조한다. 원본은 Git 제외이며 보존한다.
- 구현 결과: 승인된 세 파일 변경 완료. `codyssey_prepare_env`에 위치 인자를 전달하고 0개/3개 분기와 기존 검증을 연결했다. 메모리 비교 호출은 명시 인자로 변경했다. Implementer 정적 self-check 및 PM diff 대조 완료, 실제 실행·테스트는 미수행.
- Review Decision: REQUIRED(공용 준비 도구와 메모리 비교 호출 관계 변경). 새 Reviewer `gpt-6-sol` / `medium`, `fork_turns="none"`으로 [독립 리뷰](../reviews/REVIEW-TASK-003.md) 완료. Critical/Major/Minor 없음, PM 수정 finding 없음. 인자화 검토만 완료이며 CPU 요구사항 완료를 의미하지 않는다.
- 사용자 검증: 3개 인자 실행의 부트 설정·관제 기록, 인자 개수/범위 오류 시 미실행, 기존 무인자 및 메모리 비교 호출의 회귀 여부를 확인한다. 학습 정리는 TASK 기능·사용자 검증 완료 후 수행한다.

## 회수한 첫 관측 계획

- 기존 도구를 수정하지 않고 MEMORY_LIMIT=512, CPU_MAX_OCCUPY=80, MULTI_THREAD_ENABLE=false로 첫 실행한다. 이전 CpuWorker 기록과 비교하는 시작 후보이며 재현 성공을 보장하지 않는다.
- monitor CSV는 프로세스 수명 평균 CPU이므로 별도 터미널의 대상 PID `top` 관측으로 구간 변화를 보완한다. 첫 top 표본을 급상승 증거로 단정하지 않는다.
- 실제 Watchdog 로그와 종료 원인을 확인한 뒤 CPU_MAX_OCCUPY만 변경하는 두 번째 조건을 결정한다. 다른 장애가 먼저 발생하면 해당 한계를 기록한다.
- PM Review Decision: SKIP. 기존 도구의 실행 안내만 회수했으며 source 변경 없음. 후속 보고서는 증거·해석 범위를 보고 재판정한다.

## Requirements

### 2026-10-13 두 번째 CPU 관측

- 사용자 실행 `runs/run-2026-10-13_18-05-17-HzSxJx`에서 512/40/false 인자 적용·부트 성공·PID 7167의 CSV 생성을 확인했다. 첫 RUNNING 18:05:18부터 읽은 마지막 18:07:09까지 111초 이상 RUNNING이다. 자연 종료 시간은 아니다.
- 앱은 Healthy System Monitoring을 선택했고, Current Load 40% 도달 후 cooldown과 재상승을 반복한다. Heap 525MB에서 cache cleanup·MEMORY RECOVERED를 기록했다. 첫 80% 실행과 작업 경로가 달라 동일 작업의 단순 속도 비교로 해석하지 않는다.
- 사용자는 top 약 8%를 관찰했다고 보고했다. 앱 Current Load와 OS CPU 수치는 같은 지표로 단정하지 않으며, Watchdog·SIGTERM 입증은 여전히 미완료다.
- 3개 인자 정상 적용·앱 시작·관제 수집은 이번 사용자 실행으로 확인했다. 무인자·오류 입력·메모리 비교 회귀 검증은 별도로 미확인이다.
- 사용자 kill 종료 확인 후 CSV 마지막 RUNNING 18:09:25 및 EXITED 18:09:26을 대조했다. 첫 RUNNING 18:05:18부터 종료 관측까지 248초(4분 8초)이며, 자연 종료 수명이나 Watchdog 보호 종료 시간이 아니다. 정확한 kill 옵션은 별도로 전달받지 않았다. CPU 필수 증거 누락을 유지하며 보고서 작성 계획은 이 한계를 포함해야 한다.

- [MISSION §2·§4](../MISSION.md), [REQ-003·REQ-005](../REQUIREMENTS.md): 프로세스 CPU 급상승, Watchdog 보호 종료 증거, CPU_MAX_OCCUPY 전후 비교, 네 필수 절의 CPU 보고서.
- REQ-006: CPU 과점유에 따른 지연과 관측 지표·보호 조치를 설명한다.

## Constraints

- Linux 일반 사용자, 지정 환경변수·포트 조건 및 CPU_MAX_OCCUPY 10~100 범위를 지킨다.
- 바이너리 수정·디컴파일·역공학 금지. 기존 원본을 보존하고 표준 도구를 사용한다.
- 한 비교에서는 CPU_MAX_OCCUPY만 바꾸고 다른 조건은 동일하게 기록한다.
- 실제 실행·테스트는 사용자 담당. 미션 예시 로그를 실제 증거로 사용하지 않는다.
- CPU 관측 전에 다른 장애가 발생하거나 실제 Watchdog 근거가 부족하면 한계를 기록하고 완료를 추정하지 않는다.

## Scope

- 기존 준비·관제 도구로 재현 조건과 최소 사용자 실행 절차를 계획한다.
- 사용자 원본에서 설정·PID·시각·CPU 관측·종료 원인을 연결하고 전후 비교한다.
- CPU 보고서 신규 작성과 실제 결과에 따른 README·상태 갱신, 마감 시 학습 절 작성.
- 새 자동화 스크립트나 기존 source 수정은 필요성을 제시하고 별도 구현 계획 승인을 받아야 한다.

## Out of Scope

Deadlock 본 실험, 스케줄링 보너스, TASK-002 실패 주입, 신규 프레임워크·자동 분석기, 실제 게시·제출·Git 쓰기.

## Acceptance Criteria

- [ ] 대상 PID의 CPU 급상승 구간을 관제 또는 top/ps로 확보한다.
- [ ] 실행 로그로 Watchdog 보호 종료를 입증한다.
- [ ] CPU_MAX_OCCUPY 변경 전후 종료 여부 또는 생존 시간 변화를 동일 기준으로 비교한다.
- [ ] 보고서의 현상·증거·원인·조치 및 검증 네 절을 실제 결과로 작성한다. Git 제외 원본의 핵심 근거는 출처와 함께 발췌한다.
- [ ] 필요한 리뷰·사용자 확인 및 최종 학습 정리를 완료한다. 이해 완료는 별도 확인한다.

## Relevant Files

- [prepare-env.sh](../../../prepare-env.sh), [monitor.sh](../../../monitor.sh): 재사용 우선.
- [메모리 비교 스크립트](../../../run-memory-comparison.sh), [OOM 보고서](../../reports/oom.md): 이전 실험과 한계 참고, 기존 메모리 기능 보존.
- [README](../../../README.md), [학습 노트](../../study-note.md).
- [CPU 보고서 초안](../../reports/cpu.md).

## Implementation Notes

기존 512MB 실행에는 CpuWorker 임계치 위반이 있지만 실제 Watchdog 신호와 내부 판정 이유는 미확인이다. 새 실험 결과를 예상하지 않는다. 관제 CPU 지표의 측정 구간과 앱 지표의 차이를 확인한다.

## Learning Deliverable

기능·리뷰·사용자 검증 후 [학습 노트](../../study-note.md)에 CPU 과점유와 시스템 지연, 관측 지표, Watchdog, 임시 조치와 전후 비교 근거를 최종 코드·실험 기준으로 정리한다.
