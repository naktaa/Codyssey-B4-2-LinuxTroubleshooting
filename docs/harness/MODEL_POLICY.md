# 모델 사용 정책

GPT-6 계열만 사용합니다. PM은 GPT-6 Astra 전용이며, 구현과 리뷰는 GPT-6 Sol 또는 GPT-6 Luna를 사용합니다.

이 표는 사용자가 지정한 운영 정책입니다. PM 세션은 사용자가 Astra로 선택하고, PM은 아래 정책과 현재 도구의 지원 목록을 확인해 하위 에이전트의 모델·reasoning을 명시합니다. 지원하지 않는 설정을 임의로 대체하지 않습니다.

| 역할 | 사용할 모델 ID | 책임 |
| --- | --- | --- |
| PM | `gpt-6-astra` | 미션 분석, Step·TASK 설계, 모델 지정, 승인 요청, 위임·결과 회수, Review 판단·Triage, 상태 관리 |
| Implementer | `gpt-6-luna` / `gpt-6-sol` | 읽기 전용 계획 반환 후 승인된 TASK 구현 |
| Reviewer | `gpt-6-luna` / `gpt-6-sol` | 구현 대화를 상속하지 않는 새 에이전트에서 독립 검토·보고 |

GPT-6 Astra를 Implementer나 Reviewer로 사용하지 않습니다. PM은 기능 source를 구현하지 않습니다.

| 난이도 | 예시 | 기본 모델 | Reasoning |
| --- | --- | --- | --- |
| LOW | 작은 UI/CSS/문서 수정, 원인이 명확한 작은 bug | GPT-6 Luna | Low |
| MEDIUM | 일반 기능, CRUD, API, React component, Python module, 파일 입출력, 일반 refactoring | GPT-6 Sol | Medium |
| HIGH | 여러 module, 복잡한 상태·동시성·데이터 무결성, 원인 불명 bug, architecture 영향, 구현 대안 비교 | GPT-6 Sol | High |

절대 대응표가 아닙니다. PM은 작업 특성과 영향 범위를 근거로 한 줄 이유를 붙입니다. MEDIUM에 High reasoning을 권할 수도 있습니다. 항상 가장 강한 모델을 선택하지 않습니다.
Reviewer 모델도 변경 위험과 검토 난이도로 별도 추천합니다.
지정 모델이나 reasoning이 현재 도구에 없거나 호출이 실패하면 PM이 실패와 가능한 선택지를 알립니다. 다른 모델로 자동 전환하지 않습니다. `gpt-6.1-sol`이 제공되더라도 이 정책의 `gpt-6-sol`을 임의로 바꾸지 않습니다.

## 현재 환경에서의 지정 방법

2026-10-08 확인: 설치된 CLI는 `codex-cli 0.162.0-alpha.2`이며, 이 채팅에 제공된 `collaboration.spawn_agent`는 `task_name`, `message`, `model`, `reasoning_effort`, `fork_turns`를 받습니다. CLI 버전만으로 채팅 기능을 보증하지 않으며 실제 제공된 도구 계약을 우선합니다.

- 지원 목록에 `gpt-6-astra`, `gpt-6-sol`, `gpt-6-luna`와 세 모델의 `low` / `medium` / `high` reasoning이 있습니다. 이 하네스는 기존 난이도 표의 세 수준을 사용합니다. PM의 reasoning은 사용자가 선택한 지원 설정을 유지합니다.
- 생성 시 `model`과 `reasoning_effort`를 명시하고 `fork_turns="none"`을 사용합니다. 전체 대화 상속(`all` 또는 생략)은 부모 모델·reasoning을 상속하며 현재 도구에서 override를 받지 않으므로 역할별 모델 지정에 사용하지 않습니다.
- 역할 프롬프트 경로, TASK, 현재 단계, 기준점, 승인 범위와 결과 형식은 `message`로 전달합니다. Reviewer에는 구현자의 대화·결론을 정답으로 전달하지 않습니다.
- 생성 결과의 실제 식별자로 `followup_task`를 호출해 후속 단계를 지시합니다. `send_message`는 실행 중 안내이며 유휴 에이전트를 재개하지 않습니다. `list_agents`·`wait_agent`로 상태·결과를 확인하고 필요한 경우 `interrupt_agent`를 사용합니다. 결과 본문과 실제 파일을 확인한 뒤에만 다음 단계로 갑니다.
- 현재 도구에 에이전트별 sandbox나 custom agent 파일 선택 인수는 없습니다. 별도 `.codex/agents/` 설정의 적용을 가정하지 않고 기존 역할 문서를 전달합니다. 읽기 전용 지시는 운영 규칙이며 OS 쓰기 권한 차단을 보증하지 않습니다.

예: Implementer 계획 호출은 `model="gpt-6-sol"`, `reasoning_effort="medium"`, `fork_turns="none"`과 계획 단계 지시를 전달합니다. Reviewer도 별도 생성하고 같은 방식으로 정책 내 모델을 지정합니다. 별도 API나 설정 파일은 필요하지 않습니다.

## 지원·실행 확인의 구분

도구 계약의 지원 목록, 호출에 지정한 설정, 도구가 수락하고 반환한 결과, 실행 모델 메타데이터를 구분해 기록합니다. 에이전트가 자기 모델명을 말하는 것만으로 실제 실행 모델을 검증했다고 쓰지 않습니다. 현재 부모 모델 ID를 조회하는 도구는 확인되지 않았으므로 PM이 Astra로 실행 중이라고 추정하지 않습니다. 사용자의 모델 선택 화면 등 확인 가능한 근거가 없으면 미확인으로 보고하고, 다른 모델임이 확인되면 PM 역할 작업을 계속하지 말고 사용자에게 알립니다.

실제 읽기 전용 위임 결과와 확인하지 못한 설정은 [WORKLOG.md](WORKLOG.md)에 남깁니다. 새 환경에서는 도구·모델 지원을 다시 확인합니다. 공식 기능 설명: [OpenAI Subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents). 공식 문서의 일반 기능을 현재 도구의 검증 결과로 대체하지 않습니다.
