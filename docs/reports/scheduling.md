# [Analysis] 정상 실행 로그의 스케줄링 패턴 추론

## 1. 로그 관찰 개요

`Healthy System Monitoring` 정상 실행에서 앱은 `Thread-A`, `Thread-B`, `Thread-C`를 이 순서로 등록했다. A가 완료된 뒤 B가 시작하고, B가 완료된 뒤 C가 시작했다. 이는 앱 로그에 나타난 작업 처리 순서이며, OS 스레드의 실제 CPU 점유 순서나 스케줄링 정책을 직접 측정한 결과는 아니다.

## 2. 증거 자료

정상 실행의 앱 로그

```text
16:29:40,237 [INFO] [Scheduler] Registered Tasks: ['Thread-A', 'Thread-B', 'Thread-C']
16:29:40,237 [INFO] [Thread-A] Task Started. Calculating... (20%)
16:29:40,289 [INFO] [Thread-A] Calculating... (40%)
16:29:40,340 [INFO] [Thread-A] Calculating... (60%)
16:29:40,391 [INFO] [Thread-A] Calculating... (80%)
16:29:40,443 [INFO] [Thread-A] Task Completed. (100%)
16:29:40,495 [INFO] [Thread-B] Task Started. Calculating... (20%)
16:29:40,558 [INFO] [Thread-B] Calculating... (40%)
16:29:40,609 [INFO] [Thread-B] Calculating... (60%)
16:29:40,660 [INFO] [Thread-B] Calculating... (80%)
16:29:40,711 [INFO] [Thread-B] Task Completed. (100%)
16:29:40,762 [INFO] [Thread-C] Task Started. Calculating... (20%)
16:29:40,814 [INFO] [Thread-C] Calculating... (40%)
16:29:40,865 [INFO] [Thread-C] Calculating... (60%)
16:29:40,917 [INFO] [Thread-C] Calculating... (80%)
16:29:40,968 [INFO] [Thread-C] Task Completed. (100%)
16:29:41,019 [INFO] [Scheduler] All tasks completed.
```

| 작업 | 시작→완료 기록 간격 | 다음 작업 시작까지의 기록 간격 |
| --- | ---: | ---: |
| A | 206ms | 52ms |
| B | 216ms | 51ms |
| C | 206ms | 해당 없음 |

각 작업의 진행률은 20→40→60→80→100%로 이어지고, 한 작업의 완료 전에 다른 작업의 진행 로그가 끼어들지 않는다. 진행 기록은 대체로 약 51~52ms 간격이며 B의 첫 두 기록은 63ms 차이다. 이 값은 **로그 기록 간격**으로, CPU 사용 시간이나 Round-Robin의 시간 할당량(quantum)을 뜻하지 않는다.

## 3. 패턴 분석 및 결론

| 알고리즘 | 설명 | 로그상 가능성 |
| --- | --- | --- |
| FCFS | 먼저 도착한 작업을 먼저 처리한다. | 등록·완료 순서와 A→B→C 순차 완료가 FCFS형 패턴과 맞는다. 실제 도착 순서는 기록되지 않아 확정할 수 없다. |
| SJF | 예상 실행 시간이 가장 짧은 작업을 먼저 처리한다. | 작업별 예상 실행 시간과 선택 시점의 대기 작업을 알 수 없어 같은 순서였는지 판단할 수 없다. |
| SRT | 남은 예상 실행 시간이 가장 짧은 작업을 우선한다. | 남은 시간의 추정값과 새 작업의 도착 시각이 없어 선점 여부나 선택 기준을 판단할 수 없다. |
| RR | 실행 가능한 작업에 정해진 시간 할당량씩 차례로 기회를 준다. | 완료 전 다른 작업의 진행 로그는 없지만, 할당량이 작업 길이보다 길거나 교체가 로그에 드러나지 않았다면 이 순서도 가능하다. |
| Priority | 작업별 우선순위에 따라 처리한다. | 작업별 우선순위 값이 없어 A→B→C 순서가 우선순위 결과인지 구별할 수 없다. |
| HRN | 대기 시간과 예상 실행 시간으로 계산한 응답률이 가장 높은 작업을 먼저 처리한다. | 도착 시각·대기 시간·예상 실행 시간이 없어 응답률과 선택 기준을 판단할 수 없다. |

**결론:** 관찰된 A→B→C 순차 완료는 FCFS형 처리와 맞는다. 그러나 여섯 후보를 구별하는 입력과 선택 시점이 로그에 없으므로 실제 앱 또는 OS의 알고리즘을 확정하거나 후보의 순위를 매길 수 없다. `Thread-A/B/C`는 앱의 로그 레이블이며 OS 스레드 식별 정보가 아니다.
