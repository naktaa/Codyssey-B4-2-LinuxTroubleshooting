# Review: TASK-005 실행 시각 접두어와 기존 증거 이동

- 대상: [TASK-005](../tasks/TASK-005.md)의 후속 사용자 승인(실행 폴더 시각 접두어, 당시 현존한 7개 증거 폴더 이름, 관련 문서 경로). 기준점은 `4335e76`이며 현재 작업 트리의 [prepare-env.sh](../../../prepare-env.sh), [README.md](../../../README.md), 해당 7개 `runs/` 목적지와 문서 변경을 정적으로 확인했다. `runs/`는 Git 제외 대상이므로 폴더 이동은 `git diff`에 나타나지 않는다.
- 독립성·범위: 구현 대화를 상속하지 않았다. 최초 7개 이후 추가된 실행 폴더와 사용자 별도 `run-memory-comparison.sh` (삭제 전), `memory-test.sh` (삭제 전), [kill-agent-leak.sh](../../../kill-agent-leak.sh)의 변경은 이번 평가에서 제외했다. 앱·스크립트·테스트를 실행하거나 source·증거를 수정하지 않았다.
- 검증 한계: 현재 목적지의 26개 파일은 확인했지만 이동 **전** 상대 경로·SHA-256 manifest 원본은 Reviewer에게 없어 전후 바이트 동일성을 독립 검증할 수 없다. Implementer의 전후 manifest 동일 보고는 검증된 사실로 바꾸지 않는다. 이름과 현재 내용의 정적 일치만 판정한다. 실제 새 실행과 파일 실패 경로도 검증하지 않았다.

## Critical

없음.

## Major

없음.

## Minor

없음.

## Good

- [prepare-env.sh](../../../prepare-env.sh) `codyssey_prepare_env` 66~85행, 116~145행: 검증한 세 입력값을 폴더 이름에서만 정규화하고, `date +%y%m%d-%H%M%S`와 `mktemp -d ...-XXXXXX`로 시각 접두어와 6자리 고유 접미어를 만든다. 앱에 내보내는 `MEMORY_LIMIT`·`CPU_MAX_OCCUPY`·`MULTI_THREAD_ENABLE`은 원래 입력값이고 `run_dir`·`AGENT_LOG_DIR`은 같은 새 경로다. `launch_local` 기록도 유지한다. 이름의 시각은 초 단위이므로 같은 초 안에서 만든 폴더끼리는 접미어의 문자순이 실제 시작 순서를 나타내지 않는다.
- [TASK-005](../tasks/TASK-005.md) 72~82행의 7개 매핑은 현재 목적지 7개와 일치한다. 각 [CPU 첫 실행 앱 로그](../../../runs/261026-160154_512_80_false-2PYjC0/app.log)·[CPU 80% 앱 로그](../../../runs/261027-155944_512_80_false-5osiuy/app.log)·[CPU 40% 앱 로그](../../../runs/261027-161341_512_40_false-binP1r/app.log)·[교착 true 앱 로그](../../../runs/261026-175455_512_40_true-kFiIRQ/app.log)·[교착 false 앱 로그](../../../runs/261026-180002_512_40_false-1munWl/app.log)와 [16:31 앱 로그](../../../runs/261026-163156_512_80_false-69clnq/app.log)·[16:38 앱 로그](../../../runs/261026-163822_512_80_false-JtWmJF/app.log)의 1행 `launch_local`, 12행 옛 절대 경로, 14행 설정을 대조했다. 새 폴더의 시각·세 설정·기존 6자리 식별자가 모두 맞고, 현재 로그에는 실행 당시 옛 절대 경로가 남아 있다. 이는 올바른 매핑과 원본 형태를 뒷받침하지만 전후 해시 동일성 증명은 아니다.
- [WORKLOG.md](../WORKLOG.md), [TASK-003](../tasks/TASK-003.md), [TASK-004](../tasks/TASK-004.md), [CPU 보고서](../../reports/cpu.md), [교착 보고서](../../reports/deadlock.md), [CPU 보고서 리뷰](REVIEW-TASK-003-CPU-REPORT.md), [교착 보고서 리뷰](REVIEW-TASK-004-DEADLOCK-REPORT.md), [학습 노트](../../study-note.md)의 새 실행 증거 링크 92개는 현재 해당 파일을 가리킨다. `#L` 앵커도 대상 파일의 실제 행 수 이내다. CPU 80%·40%와 교착 true·false의 연결이 해당 폴더 설정과 일치한다. 대상 7개의 옛 이름은 [TASK-005 매핑](../tasks/TASK-005.md)에만 역사 기록으로 남았다.
- [README.md](../../../README.md) 45행과 62~74행은 새 형식과 정규화·원래 앱 설정 유지, 사용자 수동 종료, 새 메모리 관측의 미검증 상태를 설명한다. 앞선 [REVIEW-TASK-005](REVIEW-TASK-005.md)의 Major-1·Minor-1 대상인 `observe-memory.sh`는 이번 시각 접두어 변경 범위에서 수정되지 않았으므로 그 리뷰의 정적 해결 판정을 뒤집는 새 근거는 발견하지 못했다.

## PM Disposition

- Critical/Major/Minor finding 없음. 추가 수정 계획은 없다. 후속 독립 리뷰는 이 문서로 완료했고 추가 리뷰는 SKIP한다.
- Implementer는 26개 파일의 이동 전후 상대 경로·SHA-256 일치를 보고했다. 리뷰어는 이동 전 manifest 원본을 확보하지 못해 이를 독립 검증하지 않았으므로 무결성 결론의 근거 수준을 구분한다.
- 새 폴더 생성은 사용자 실행의 [17:40:57 앱 로그](../../../runs/261027-174057_512_40_false-kz262f/app.log)에서 형식·설정·부트 표식을 부분 확인했다. 공통 `observe.sh`의 mode별 실행과 `observe-memory.sh`의 시간 만료·오류 경로는 별도 사용자 검증이 필요하다.
