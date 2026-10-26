# 모델 사용 정책

2026-10-26 사용자 승인부터 PM은 GPT-6.1 Sol / High, Implementer와 Reviewer는 GPT-6.1 Sol / Medium으로 고정합니다. 과거 TASK·리뷰·WORKLOG의 모델 기록은 당시 실행 이력이므로 변경하지 않습니다.

이 표는 사용자가 지정한 운영 정책입니다. PM 세션은 사용자가 GPT-6.1 Sol / High로 선택하고, PM은 아래 정책과 현재 도구의 지원 목록을 확인해 하위 에이전트의 모델·reasoning을 명시합니다. 지원하지 않는 설정을 임의로 대체하지 않습니다.

| 역할 | 사용할 모델 ID | Reasoning | 책임 |
| --- | --- | --- | --- |
| PM | `gpt-6.1-sol` | High | 미션 분석, Step·TASK 설계, 승인 요청, 위임·결과 회수, Review 판단·Triage, 상태 관리 |
| Implementer | `gpt-6.1-sol` | Medium | 읽기 전용 계획 반환 후 승인된 TASK 구현 |
| Reviewer | `gpt-6.1-sol` | Medium | 구현 대화를 상속하지 않는 새 에이전트에서 독립 검토·보고 |

PM은 기능 source를 구현하지 않습니다. 역할별 모델·reasoning은 난이도에 따라 자동 변경하지 않습니다.

| 난이도 | 예시 |
| --- | --- |
| LOW | 작은 문서 수정, 원인이 명확한 작은 bug |
| MEDIUM | 일반 기능, 파일 입출력, 일반 refactoring |
| HIGH | 복잡한 상태·동시성·데이터 무결성, 원인 불명 bug, architecture 영향 |

PM은 작업 특성과 영향 범위로 난이도·Review 등급을 판단하되 모델·reasoning은 위 역할 표를 따릅니다. 지정 설정을 지원하지 않거나 호출이 실패하면 실패와 가능한 선택지를 알립니다. 다른 모델이나 reasoning으로 자동 전환하지 않습니다. 정책 변경은 사용자 승인이 필요합니다.

## 현재 환경에서의 지정 방법

2026-10-08 확인: 설치된 CLI는 `codex-cli 0.162.0-alpha.2`이며, 이 채팅에 제공된 `collaboration.spawn_agent`는 `task_name`, `message`, `model`, `reasoning_effort`, `fork_turns`를 받습니다. CLI 버전만으로 채팅 기능을 보증하지 않으며 실제 제공된 도구 계약을 우선합니다.

- 2026-10-26 현재 도구 계약은 `gpt-6.1-sol`과 `medium` / `high` reasoning 지정을 지원합니다. PM High는 사용자 선택으로 유지하고, Implementer·Reviewer는 생성 시 Medium을 명시합니다.
- 생성 시 `model`과 `reasoning_effort`를 명시하고 `fork_turns="none"`을 사용합니다. 전체 대화 상속(`all` 또는 생략)은 부모 모델·reasoning을 상속하며 현재 도구에서 override를 받지 않으므로 역할별 모델 지정에 사용하지 않습니다.
- 역할 프롬프트 경로, TASK, 현재 단계, 기준점, 승인 범위와 결과 형식은 `message`로 전달합니다. Reviewer에는 구현자의 대화·결론을 정답으로 전달하지 않습니다.
- 생성 결과의 실제 식별자로 `followup_task`를 호출해 후속 단계를 지시합니다. `send_message`는 실행 중 안내이며 유휴 에이전트를 재개하지 않습니다. `list_agents`·`wait_agent`로 상태·결과를 확인하고 필요한 경우 `interrupt_agent`를 사용합니다. 결과 본문과 실제 파일을 확인한 뒤에만 다음 단계로 갑니다.
- 현재 도구에 에이전트별 sandbox나 custom agent 파일 선택 인수는 없습니다. 별도 `.codex/agents/` 설정의 적용을 가정하지 않고 기존 역할 문서를 전달합니다. 읽기 전용 지시는 운영 규칙이며 OS 쓰기 권한 차단을 보증하지 않습니다.

예: Implementer 계획 호출은 `model="gpt-6.1-sol"`, `reasoning_effort="medium"`, `fork_turns="none"`과 계획 단계 지시를 전달합니다. Reviewer도 별도 생성하고 같은 설정을 지정합니다. 기존 다른 모델의 에이전트는 재사용하지 않고 새로 생성합니다. 별도 API나 설정 파일은 필요하지 않습니다.

## 지원·실행 확인의 구분

도구 계약의 지원 목록, 호출에 지정한 설정, 도구가 수락하고 반환한 결과, 실행 모델 메타데이터를 구분해 기록합니다. 에이전트가 자기 모델명을 말하는 것만으로 실제 실행 모델을 검증했다고 쓰지 않습니다. PM의 모델 ID는 제공된 실행 컨텍스트로 확인할 수 있는 경우에만 확인됐다고 쓰며, reasoning은 별도 확인 근거가 없으면 사용자 지정 High와 실제 검증 여부를 구분합니다. 정책과 다른 설정으로 실행 중임이 확인되면 사용자에게 알립니다.

실제 읽기 전용 위임 결과와 확인하지 못한 설정은 [WORKLOG.md](WORKLOG.md)에 남깁니다. 새 환경에서는 도구·모델 지원을 다시 확인합니다. 공식 기능 설명: [OpenAI Subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents). 공식 문서의 일반 기능을 현재 도구의 검증 결과로 대체하지 않습니다.
