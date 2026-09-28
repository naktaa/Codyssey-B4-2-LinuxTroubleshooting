# 모델 사용 정책

GPT-6 계열만 사용합니다. PM은 GPT-6 Astra 전용이며, 구현과 리뷰는 GPT-6 Sol 또는 GPT-6 Luna를 사용합니다.

이 표는 사용자가 지정한 운영 정책입니다. 모델의 현재 제공 여부나 성능 순위를 보증하는 자료가 아닙니다. 모델과 reasoning은 사용자가 세션 생성 시 직접 선택합니다.

| 역할 | 사용할 모델 | 책임 |
| --- | --- | --- |
| PM | GPT-6 Astra만 | 미션 분석, Step·TASK 설계, 난이도·모델 추천, 구현 결과 확인, Review 판단·Triage, 상태 관리 |
| Implementer | GPT-6 Luna / GPT-6 Sol | 계획 제시 후 승인된 TASK 구현 |
| Reviewer | GPT-6 Luna / GPT-6 Sol | 독립 세션에서 문제 발견·보고 |

GPT-6 Astra를 Implementer나 Reviewer로 사용하지 않습니다. PM은 기능 source를 구현하지 않습니다.

| 난이도 | 예시 | 기본 모델 | Reasoning |
| --- | --- | --- | --- |
| LOW | 작은 UI/CSS/문서 수정, 원인이 명확한 작은 bug | GPT-6 Luna | Low |
| MEDIUM | 일반 기능, CRUD, API, React component, Python module, 파일 입출력, 일반 refactoring | GPT-6 Sol | Medium |
| HIGH | 여러 module, 복잡한 상태·동시성·데이터 무결성, 원인 불명 bug, architecture 영향, 구현 대안 비교 | GPT-6 Sol | High |

절대 대응표가 아닙니다. PM은 작업 특성과 영향 범위를 근거로 한 줄 이유를 붙입니다. MEDIUM에 High reasoning을 권할 수도 있습니다. 항상 가장 강한 모델을 선택하지 않습니다.
Reviewer 모델도 변경 위험과 검토 난이도로 별도 추천합니다.
지정 모델이나 reasoning이 선택 화면에 없으면 사용 가능하다고 가정하거나 몰래 대체하지 말고, 사용자에게 가능한 선택지를 확인해 정책 변경을 논의합니다.
