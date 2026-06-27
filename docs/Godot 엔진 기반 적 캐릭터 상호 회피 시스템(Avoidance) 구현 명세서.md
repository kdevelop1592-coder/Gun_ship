### Godot 엔진 기반 적 캐릭터 상호 회피 시스템(Avoidance) 구현 명세서

본 명세서는 Godot 엔진의 NavigationAgent를 활용하여 다수의 에이전트가 복잡한 동적 환경 내에서 상호 간섭 없이 유기적으로 이동하도록 설계된 '상호 회피 시스템'의 아키텍처와 구현 공정을 정의합니다.

#### 1\. 개요: 적 캐릭터 AI 상호 회피 시스템의 전략적 가치

단순한 길찾기(Pathfinding)가 목적지까지의 최단 경로를 도출하는 것이라면, 상호 회피(Avoidance)는 다수의 AI 에이전트가 밀집된 공간에서 물리적 충돌과 병목 현상을 방지하며 이동의 질을 결정하는 핵심 기술입니다. Senior Architect의 관점에서, Godot의 NavigationServer를 통한 상호 회피 시스템은 단순한 충돌 처리를 넘어 \*\*비동기 상태 동기화(Asynchronous State Synchronization)\*\*를 통한 성능 최적화와 UX 고도화를 달성하는 데 목적이 있습니다.이 시스템은 에이전트 간의 물리적 밀쳐냄(Jittering)을 최소화하고, 다수의 적이 플레이어를 자연스럽게 포위하거나 장애물을 우회하게 함으로써 게임의 몰입감을 극대화합니다. 이는 개발자가 각 에이전트의 로컬 충돌 로직을 수동으로 관리해야 하는 비용을 획기적으로 절감시킵니다.

#### 2\. 에이전트 설정(Avoidance Configuration): 속성 최적화 및 상관관계 분석

상호 회피 시스템의 안정성은 NavigationAgent 노드의 속성값 설정에서 시작됩니다. 이 값들은 내비게이션 서버가 '안전 벡터(Safe Vector)'를 계산하는 기초 데이터가 됩니다.| 속성 (Attribute) | 설정값의 정의 | 실제 적용 시 설계 고려사항 || \------ | \------ | \------ || **Radius** | 에이전트의 회피 반경 | 캐릭터의  **Collision Shape 크기(예: 16px)와 반드시 일치** 시켜 물리 엔진과 내비게이션 서버 간의 데이터 일관성을 보장해야 합니다. || **Neighbor Distance** | 이웃 탐색 범위 | 회피 계산 시 고려할 주변 에이전트의 감지 거리입니다. 과도하게 넓을 경우 불필요한 계산 비용이 발생합니다. || **Max Neighbors** | 고려 대상 최대 수 | 회피 연산에 포함할 최대 이웃 에이전트 수입니다. 성능 비용과 직결되므로 최적화의 핵심 지표가 됩니다. || **Time Horizon** | 경로 예측 시간 | 미래의 충돌을 방지하기 위해 이동 경로를 시뮬레이션하는 시간(초)입니다. || **Max Speed** | 최대 이동 속도 | 에이전트의 물리적 이동 속도(예: 100px/s)와 일치시켜 서버가 계산한 회피 속도가 실제 물리 한계 내에서 작동하도록 제약합니다. |

##### 핵심 분석 Max Neighbors와 Time Horizon의 상관관계

Senior Architect로서 강조하는 핵심은 Time Horizon과 Max Neighbors의 비판적 균형입니다. Time Horizon을 높여 미래의 경로를 더 멀리 예측(예: 2.0s 이상)할 경우, 에이전트는 더 넓은 범위의 잠재적 충돌 대상을 고려해야 합니다. 이때 Max Neighbors가 너무 낮게 설정되어 있다면, 에이전트는 먼 미래에 충돌할 대상은 인지하지만, 정작 그 사이에 끼어드는 제3의 에이전트를 계산에서 누락시켜 예측이 빗나가는 \*\*논리적 결함(Look-ahead Buffer Miss)\*\*이 발생합니다. 따라서 예측 시간을 늘릴수록 고려해야 할 이웃의 수도 전략적으로 늘려야만 시스템의 신뢰성을 확보할 수 있습니다.

#### 3\. 신호 기반 아키텍트: velocity\_computed 피드백 루프

회피 시스템은 즉각적인 물리 적용이 아닌,  **NavigationServer와 에이전트 간의 비동기 통신**  구조를 갖습니다.

1. **의도 전달(Intent Submission):**  에이전트가 목표 지점으로 가기 위한 '의도된 속도(Intended Velocity)'를 서버에 전송합니다.  
2. **서버 연산(Server-side Computation):**  NavigationServer는 프레임 종료 시점에 모든 에이전트의 위치와 속도를 취합하여 충돌이 없는 '안전한 속도(Safe Velocity)'를 계산합니다.  
3. **결과 반환(Signal Emission):**  계산이 완료되면 서버는 velocity\_computed 시그널을 발생시키고, 에이전트는 이 신호를 받았을 때만 실제 물리 이동을 수행합니다.이 구조는 내비게이션 서버의 연산 부하를 프레임 단위로 분산시키며, 다수의 에이전트가 복잡하게 얽힌 상황에서도 결정론적(Deterministic)인 이동 결과를 보장합니다.

#### 4\. 코드 리팩토링 가이드: '수술적' 접근을 통한 로직 전환

기존의 동기적 이동 로직을 NavigationServer의 비동기 피드백 루프로 전환하는 과정입니다.

##### Step 1: 물리 프로세스 수정 (의도와 물리 분리)

기존 \_physics\_process 내에서 직접 velocity를 할당하고 move\_and\_slide()를 호출하던 로직을 제거합니다.  
\# \[Before Surgery\] 직접 제어 방식 (Avoidance 미적용)  
\# velocity \= direction \* speed  
\# move\_and\_slide()

\# \[After Surgery\] 의도 전달 방식  
var axis \= (player.global\_position \- global\_position).normalized()  
var intended\_velocity \= axis \* speed \# 로컬 변수로 '의도'만 생성

##### Step 2: 속도 전달 (Server Request)

계산된 intended\_velocity를 navigation\_agent.set\_velocity()를 통해 서버에 전달합니다. 이 시점에서 에이전트는 아직 움직이지 않으며, 서버의 승인을 기다리는 대기 상태가 됩니다.  
navigation\_agent.set\_velocity(intended\_velocity)

##### Step 3: 시그널 연결 및 실행 (Execution)

서버가 안전한 속도를 계산하여 돌려주는 시점에 실제 이동을 확정합니다.

* **Signal Connection:**  Godot 에디터의 Node 탭 또는 \_ready() 함수 내에서 velocity\_computed 시그널을 \_on\_velocity\_computed 함수에 연결합니다.  
* **Architectural Warning:**  이 방식은 \*\*1프레임의 지연(One-frame Delay)\*\*이 내재되어 있습니다. set\_velocity()를 호출한 즉시 move\_and\_slide()가 실행되는 것이 아니라, 서버 연산이 끝난 다음 프레임의 콜백 시점에서 이동이 발생하기 때문입니다.

func \_on\_navigation\_agent\_velocity\_computed(safe\_velocity: Vector3):  
    \# 서버로부터 검증된 safe\_velocity를 클래스 속성 velocity에 할당  
    velocity \= safe\_velocity   
    \# 비로소 물리 연산 실행  
    move\_and\_slide()

#### 5\. 시스템 안정성 및 예측 가능성 검증

시스템 구축 후 실제 게임 플레이 환경에서의 동작을 분석하고 개선하는 단계입니다.

##### 디버깅 및 테스트 전략

* **D-aggro(De-aggro) Range 조정:**  적 캐릭터가 플레이어를 추적하는 범위를 일시적으로 확장하여, 좁은 공간에 다수의 에이전트가 밀집하게 유도함으로써 회피 알고리즘의 한계 상황(Stress Test)을 검증합니다.  
* **Collision Shapes 런타임 비활성화:**  물리 충돌체에 의한 강제 밀어내기가 아닌, Radius 설정에 기반한 순수 RVO(Reciprocal Velocity Obstacle) 알고리즘이 의도대로 안전 벡터를 생성하는지 시각적으로 확인합니다.

##### 현안 및 향후 개선 방향: Player Pushing 문제

현재 시스템에서 적 에이전트가 플레이어의 중심점(Origin)을 타겟팅할 경우, 에이전트들이 플레이어를 물리적으로 밀어내는 현상이 발생할 수 있습니다. 이를 해결하기 위해 향후 다음과 같은 아키텍처 확장이 필요합니다:

1. **Relative Positioning:**  플레이어의 절대 위치가 아닌, 플레이어 주변의 특정 오프셋 지점을 타겟팅하도록 로직을 수정합니다.  
2. **Priority System:**  플레이어와 적 에이전트 간의 회피 우선순위를 설정하여 플레이어가 AI에 의해 밀리지 않도록 설계적 제약을 추가합니다.**결론:**  본 명세서의 신호 기반 아키텍처와 속성 최적화는 Godot 엔진에서 AI 에이전트 간의 상호작용을 체계화하고, 대규모 적 군집 상황에서도 안정적인 물리 퍼포먼스를 유지하는 토대가 될 것입니다.

