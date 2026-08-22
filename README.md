# Jellyfish Tracker

> A public-data-driven iOS app that helps people explore the coast of
> Gyeongsangbuk-do with greater confidence.

**JunctionX Korea 2026 Track 1**

Jellyfish Tracker is a project by Team 35, Mokto Puzzle. We are building an iOS
app that analyzes public and
near-real-time data to visualize jellyfish occurrence risk along the coast of
Gyeongsangbuk-do.

## The Problem

Jellyfish are no longer just an unpleasant surprise at the beach. During the
2024 summer season, 987 jellyfish sting incidents were reported across beaches
on the Gyeongsangbuk-do coast. Visitor numbers at 24 beaches in Pohang,
Gyeongju, Yeongdeok, and Uljin fell by 24.4% year over year. The same outbreak
also damaged fishing gear and reduced the commercial value of catches.

The problem continued beyond a single exceptional season. Gyeongsangbuk-do
recorded 450 beach sting incidents in 2025, and jellyfish remained a major
safety concern ahead of the 2026 beach season.

For visitors, existing warnings can be difficult to translate into a simple
decision. They need to know where they can safely enjoy the coast today.
**Jellyfish Tracker** aims to turn scattered observations and environmental data
into an accessible, location-based view of risk.

## Our Solution

The MVP is a **data-driven jellyfish occurrence map** for tourists and beachgoers
in Gyeongsangbuk-do. It will collect available public and near-real-time data,
analyze conditions related to jellyfish occurrence, and present the results on
an intuitive iOS map.

The first version will focus on:

- Visualizing jellyfish occurrence information by coastal location
- Analyzing available observations and environmental data
- Helping visitors compare conditions before choosing a beach or entering the water

This service is intended to support safer decisions, not to replace official
marine forecasts, safety notices, or on-site guidance.

## Public Data and Analysis

The current prototype combines NIFS regional jellyfish reports with KHOA and
KMA marine data. The movement model runs a particle ensemble from each NIFS
regional estimate and calculates a 24-hour forecast using time-varying current,
wind, wave, and water-temperature forcing.

- NIFS: report time, species, density, regional occurrence and outlook
- KHOA HF current: latest observed current where local coverage is available
- KHOA ROMS: forecast current and water temperature
- KHOA numerical tidal-current map: gridded direction and speed for the
  Gyeongsangbuk-do coast, sampled every three hours from 0 to +24 hours
- KMA marine forecast: wind, waves, precipitation and water temperature
- Korea Tourism Organization: beach location and tourism information

The tidal-current API returns speed in `cm/s`; the client converts it to `m/s`.
Nearshore tidal current and the broader ROMS tendency are fused as vectors
(70:30) before particle integration. Missing sources degrade independently so
one failed feed does not invalidate all model output.

NIFS publications describe regional distributions rather than exact raw sighting
coordinates. Therefore the starting point is explicitly treated as a regional
estimate with spatial uncertainty, not an exact observation.

## Future Improvements

- Community jellyfish sighting reports
- Photo-based jellyfish identification
- Personalized alerts for nearby occurrence risk
- Support for fishers and broader coastal areas

## Team

**Team 35, Mokto Puzzle**

| Member | Role |
| --- | --- |
| Donghyeon An (안동현) | Team Lead, Planning, Development |
| Minjae Son (손민재) | Planning, Development |
| Minjae Kwon (권민재) | Planning, Development |
| Subin Won (원수빈) | Planning, Design |

## Project Status

The JunctionX demo build is operational. It includes the MapKit experience,
nearby beach recommendation and comparison, timeline playback, data layers,
beach detail summaries, live-data adapters, and the particle-based jellyfish
movement model. The current Figma file is the final UI design baseline; model
work must integrate without overriding UI decisions on `develop`.

The model keeps particle identity through time, applies coastline collision to
every 30-minute integration segment, retains beached particles at their first
coastal contact, and renders a simplified route only when the complete shortcut
segment remains over water. This prevents a valid offshore marker from being
connected by an impossible line across a peninsula.

Verification as of 2026-08-23:

- Official KHOA tidal-current API returned live Gyeongsangbuk-do grid data
- Debug simulator build succeeded
- Parser and water-continuity regression tests are included
- The latest automated test launch was blocked by the local `xcrun/simctl`
  environment; this was a runner issue after successful compilation

## References

- [Jellyfish surge hurts Gyeongsangbuk-do beaches and fisheries (Newsis, 2024-08-25)](https://www.newsis.com/view/NISX20240825_0002861544)
- [Jellyfish spread to the east coast and threaten beachgoers and fishers (Kyunghyang Shinmun, 2025-07-29)](https://v.daum.net/v/20250729133129561)
- [Gyeongsangbuk-do prepares its beaches amid continued jellyfish risk (Maeil Newspaper, 2026-06-17)](https://v.daum.net/v/20260617181257739)
- [Gyeongsangbuk-do Fire Service jellyfish safety guidance (2026-07-15)](https://inseri.gb.go.kr/Main/page.do?BD_CODE=bbs_bodo&B_LEVEL=0&B_NUM=510115901&B_STEP=510115900&Start=0&V_NUM=14579&bdName=&cmd=2&dept_code=&dept_name=&key=4&mnu_uid=6792&p1=0&p2=0&tbbscode1=bbs_bodo&word=)

---

# Jellyfish Tracker | 한국어

> 공공데이터를 활용해 더 안심하고 경상북도 바다를 찾을 수 있도록 돕는
> iOS 앱입니다.

**JunctionX Korea 2026 Track 1**

Jellyfish Tracker는 위 트랙에 참가하는 35번 팀 Mokto Puzzle(목토퍼즐)의
프로젝트입니다. 공공데이터와 실시간성 데이터를
분석하여 경상북도 연안의 해파리 출몰 위험을 지도에 시각화하는 iOS 앱을
만들고 있습니다.

## 문제 정의

해파리는 이제 해수욕장에서 마주치는 단순한 불청객을 넘어섰습니다. 2024년
여름 경북 동해안 해수욕장에서는 해파리 쏘임 사고 987건이 신고됐습니다.
포항·경주·영덕·울진의 해수욕장 24곳을 찾은 피서객은 전년 대비 24.4%
감소했으며, 어망 파손과 어획물의 상품성 저하 등 어민 피해도 발생했습니다.

이는 한 해의 이례적인 사건으로 끝나지 않았습니다. 2025년에도 경북
해수욕장에서 쏘임 사고 450건이 집계됐고, 2026년 해수욕장 개장을 앞두고도
해파리는 주요 안전 대비 대상으로 다뤄졌습니다.

현재의 경보와 관측 정보만으로 관광객이 오늘 어느 바다를 안심하고 찾아갈 수
있는지 판단하기는 어렵습니다. Jellyfish Tracker는 흩어진
관측·환경 데이터를 누구나 이해할 수 있는 위치 기반 위험 정보로 바꾸고자
합니다.

## 해결 방법

**MVP: 데이터 분석 기반 해파리 출몰 지도**

MVP는 경상북도 관광객과 해수욕객을 위한 해파리 출몰 지도입니다. 활용 가능한
공공데이터와 실시간성 데이터를 수집하고, 해파리
출몰과 관련된 조건을 분석하여 직관적인 iOS 지도에 표시합니다.

첫 버전은 다음 기능에 집중합니다.

- 연안 위치별 해파리 출몰 정보 시각화
- 관측 자료와 해양·환경 데이터 분석
- 해수욕장 방문이나 입수 전 지역별 상황 비교 지원

이 서비스는 사용자의 안전한 판단을 돕기 위한 것으로, 공식 해양 예보와 안전
특보 및 현장 안전요원의 안내를 대체하지 않습니다.

## 공공데이터와 분석

현재 프로토타입은 NIFS 해파리 지역 관측·전망과 KHOA·KMA 해양 데이터를
결합합니다. NIFS 지역 추정 영역에서 입자 앙상블을 시작하고, 시간에 따라
변하는 해류·바람·파도·수온을 입력해 24시간 이동과 해수욕장 영향 가능성을
계산합니다.

- NIFS: 조사 시각, 종, 밀도, 지역별 출현과 전망
- KHOA HF 해류: 관측 범위가 있는 지역의 최신 해류
- KHOA ROMS: 예측 해류와 수온
- KHOA 수치조류도: 경북 연안의 0~24시간 격자 유향·유속(3시간 간격)
- KMA 해상예보: 바람, 파도, 강수, 수온
- 한국관광공사: 해수욕장 위치 및 관광 정보

수치조류도의 `cm/s` 유속은 모델 내부에서 `m/s`로 변환합니다. 연안 수치조류
70%와 광역 ROMS 경향 30%를 방향 벡터로 결합한 뒤 입자 이동에 적용합니다.
각 API는 독립적으로 성공·실패를 처리하여 하나의 데이터 누락이 전체 예측을
무효화하지 않도록 구성했습니다.

NIFS 공개 자료는 정확한 원시 신고 좌표가 아니라 지역 분포를 제공하므로,
출발점은 정확한 관측점이 아닌 공간 불확실성을 포함한 지역 추정값으로
명시합니다.

## 향후 개선 사항

- 사용자 참여형 해파리 목격 신고
- 사진 기반 해파리 식별
- 주변 출몰 위험 맞춤 알림
- 어민 및 더 넓은 연안 지역을 위한 기능 확장

## 팀원

**35번 팀, Mokto Puzzle(목토퍼즐)**

| 팀원 | 역할 |
| --- | --- |
| 안동현 | 팀 리더, 기획, 개발 |
| 손민재 | 기획, 개발 |
| 권민재 | 기획, 개발 |
| 원수빈 | 기획, 디자인 |

## 프로젝트 상태

JunctionX 데모 빌드는 동작 가능한 상태입니다. MapKit 지도, 주변 해수욕장
추천·비교, 타임라인, 데이터 레이어, 상세 요약, 실데이터 어댑터와 입자 기반
이동 모델이 구현되어 있습니다. 현재 Figma 파일을 최종 UI 기준으로 사용하며,
모델 통합 과정에서는 `develop`의 UI 결정을 우선합니다.

입자는 동일 ID로 시간대 전체를 추적하고, 30분 적분 구간마다 해안 충돌을
검사합니다. 육지에 닿은 입자는 최초 접촉 지점에 정착합니다. 표시 경로를
큼직하게 단순화할 때도 두 점 사이 전체가 바다인 경우에만 연결하여 반도나
육지를 가로지르는 선을 만들지 않습니다.

2026-08-23 기준 공식 수치조류 API 실응답과 Debug 빌드를 확인했습니다. 관련
파서·해상 연속성 회귀 테스트 코드도 포함되어 있습니다. 마지막 자동 테스트
실행은 컴파일 이후 로컬 `xcrun/simctl` 환경 문제로 러너가 시작되지 못했습니다.

## 참고 자료

- [경북 동해안 해파리 급증에 따른 해수욕장·어가 피해 (뉴시스, 2024-08-25)](https://www.newsis.com/view/NISX20240825_0002861544)
- [남해에서 경북 동해안까지 확산된 해파리 피해 (경향신문, 2025-07-29)](https://v.daum.net/v/20250729133129561)
- [계속되는 해파리 위험에 대비하는 경북 동해안 해수욕장 (매일신문, 2026-06-17)](https://v.daum.net/v/20260617181257739)
- [경북소방본부 여름철 해파리 쏘임 사고 안전수칙 (2026-07-15)](https://inseri.gb.go.kr/Main/page.do?BD_CODE=bbs_bodo&B_LEVEL=0&B_NUM=510115901&B_STEP=510115900&Start=0&V_NUM=14579&bdName=&cmd=2&dept_code=&dept_name=&key=4&mnu_uid=6792&p1=0&p2=0&tbbscode1=bbs_bodo&word=)

# Local API configuration

For local demos, copy `Jellyfish Tracker/Jellyfish Tracker/Resources/APIKeys.example.plist`
to `APIKeys.plist` in the same directory and replace the placeholder values. The
real file is ignored by Git. Treat a built app as containing those credentials;
production deployments should call protected public-data APIs through a server proxy.
