# Review: TASK-003 CPU 실시간 관측 CSV

- 대상: [TASK-003](../tasks/TASK-003.md), [MISSION CPU 요구](../MISSION.md), [REQ-003](../REQUIREMENTS.md).
- 기준과 범위: 현재 HEAD 대비 [monitor.sh](../../../monitor.sh)·[README](../../../README.md) 변경 및 미추적 [cpu_live.py](../../../cpu_live.py)를 독립 검토했다. 별도 미추적 [live_cpu.py](../../../live_cpu.py)는 이번 변경 범위가 아니며 수정하지 않았다.
- 위임 설정: Reviewer `gpt-6-sol` / `medium`, 구현 대화 미상속 요청. 요청값과 실제 런타임 모델·reasoning 메타데이터 검증은 구분하며, 후자는 확인하지 못했다.
- 방법과 한계: 파일·diff·호출 관계와 실패 경로를 정적으로 확인했다. 앱·스크립트·테스트는 실행하지 않았으므로 실제 표본 간격, 신호 동작, CSV 생성 성공, CPU 과점유·Watchdog 증거 확보는 미검증이다. File Safety·Data Integrity와 수집 자식 수명·PID 식별을 검토했다. C/C++ Memory Safety와 credential 처리는 이 변경에 직접 해당하지 않는다.

## Critical

없음.

## Major

### Major-1: CPU 수집 시작 시 앱 PID 식별값을 대조하지 않음

[monitor.sh](../../../monitor.sh) `start_tick`·수집 시작(175, 200행)은 앱의 시작 tick을 확인하지만 Python 자식에 전달하지 않는다. [cpu_live.py](../../../cpu_live.py) `run`(65~73행)은 자신이 처음 읽은 PID의 시작 tick을 기준으로 삼는다. 두 시점 사이에 앱이 종료되고 PID가 재사용되면 Python은 다른 프로세스를 앱으로 받아들여 CPU CSV에 표본을 기록할 수 있다. 부모의 이후 식별 검사는 실패를 표시할 수 있어도 이미 남긴 잘못된 행을 제거하지 못한다. 기대 시작 tick을 Python에 전달하고 첫 `/proc` 읽기 결과와 비교한 뒤, 일치할 때만 CSV를 생성하는 것이 최소 보완이다. 실제 재현 여부는 확인하지 않았다.

## Minor

### Minor-1: 두 번째 CSV 생성 실패 시 빈 첫 파일이 남음

[cpu_live.py](../../../cpu_live.py) `run`(82~92행)은 0.1초 파일을 배타적으로 만든 뒤 1초 파일 생성에 실패하면 첫 파일을 닫고 종료한다. 이 경우 표본이 없는 빈 파일이 남아 같은 경로 재시도를 막는다. 두 번째 생성 실패 단계에서 이 호출이 새로 만든 첫 파일만 정리하거나, 남는 빈 산출물과 재시도 방법을 명확히 안내하는 방향이 적절하다. 기존 파일을 덮어쓰는 동작은 확인되지 않았다.

### Minor-2: 의도적 수집 종료를 오류 상태처럼 기록함

[monitor.sh](../../../monitor.sh) CPU 자식 회수(250~263행)는 정상 관측 시점에 Python 자식에 TERM을 보내고 종료값 143을 허용한다. 그러나 같은 파일의 요약 출력(274행)은 `CPU CSV status=143`을 그대로 기록하여 의도적 종료와 실패를 구분하지 않는다. 실제 오류와 정상 종료를 `observation.txt`에서 구분해 표시하면 수집 상태를 읽기 쉽다.

## Good

- [cpu_live.py](../../../cpu_live.py) `run`(103~106, 146~175행)은 0.1초와 약 1초 측정에 별도 기준점을 사용한다. 두 CSV의 1초 값은 0.1초 값의 재표현이 아니다.
- 같은 함수(82~101, 149~166행)는 `x` 모드로 기존 CSV를 보호하고, 앱 로그 형식의 현지 timestamp와 단일 `cpu_percent_interval` 열을 기록하며 각 구간 값이 0보다 큰 표본만 행으로 남긴다.
- [monitor.sh](../../../monitor.sh) 인자 분기(63~70행)는 기존 2인자 관제를 유지한다. 설정값 호출은 새 CPU CSV 두 개를 시작하고(181~201행), 기존 `cpu-samples.csv`를 생성하지 않는다. [README](../../../README.md) CPU 설명(69, 114행)은 앱 PID 단독 측정이 launcher·후손의 CPU를 대표하지 않는다는 한계를 명시한다.

## PM Disposition

PM 처리 대기.
