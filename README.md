# VillyFish

> Where should I go today?

VillyFish is an iOS coastal decision app for Gyeongsangbuk-do. It connects
public marine data, jellyfish reports, beach information, and a particle-based
movement model so visitors can compare nearby beaches before choosing where to
go.

The repository still uses the Xcode project and target name `Jellyfish Tracker`,
but the current product direction is VillyFish.

## Overview

A beach is not static. Safety changes by time, location, jellyfish activity,
currents, wind, waves, water temperature, and how close a projected movement
path comes to shore.

VillyFish turns those changing conditions into three simple user flows:

- **Map**: view Gyeongsangbuk-do beaches, jellyfish movement, forecast routes,
  selected ocean layers, and the currently recommended beach.
- **Compare Beaches**: compare the four nearest beaches with risk-colored cards
  and short condition summaries.
- **Location Details**: tap a beach to see jellyfish status, current, water
  temperature, best time, activity chips, and a plain-language safety summary.

The app is meant to support safer planning. It does not replace official marine
forecasts, beach safety notices, lifeguard guidance, or emergency instructions.

## Current App

The implemented iOS app focuses on the Gyeongsangbuk-do coast.

- Apple MapKit map constrained to the Gyeongsangbuk-do coastal area
- Location-aware fallback centered on the Gyeongsangbuk-do shoreline
- Header recommendation such as `Chilpo Beach is your safest choice today!`
- Timeline slider from `-24h` to `+24h`
- Ocean layer filter for predicted route, water temperature, and temperature
  visualization
- Search sheet with beach autocomplete and result/detail detents
- Beach markers with selected-state animation
- Jellyfish markers with direction-aware facing
- Nearby beach comparison screen
- Risk chips and icons for `SAFE`, `CAUTION`, and `DANGER`
- Design tokens and image assets generated from the current Figma direction

## Data Sources

VillyFish is designed around public and near-real-time data. The app can run
with bundled reference data, then upgrades to live data when API keys are
provided.

| Source | Used For |
| --- | --- |
| NIFS | Jellyfish report time, species, density, regional occurrence, outlook |
| KHOA | Currents, ROMS forecast current and water temperature, coastline, tidal-current grids |
| KMA | Wind, waves, precipitation, water temperature, marine observations |
| KTO | Beach locations and basic tourism information |
| Apple MapKit | Map, user location, distance calculation |

Live NIFS reports provide regional estimates, not exact raw sighting points. The
model treats those origins as approximate regions with spatial uncertainty.

## Jellyfish Movement Model

The prediction model converts public data into a living coastal map.

- Starts from NIFS regional jellyfish observations
- Runs a 360-particle ensemble
- Integrates movement every 30 minutes for a 24-hour forecast
- Uses current, wind, waves, and water temperature as forcing inputs
- Interpolates ocean conditions across time and nearby spatial samples
- Checks the bundled KHOA coastline mask
- Stops particles when they reach land
- Computes beach impact probability from particles entering a 5 km beach radius
- Combines potential arrival, recent sightings, marine movement, and data
  recency into visible risk states

When live sources are unavailable, each feed degrades independently and the app
falls back to reference data instead of failing the whole experience.

## Project Structure

```text
Jellyfish Tracker/
  Jellyfish Tracker/
    App/                         SwiftUI app entry point
    Data/Providers/              Mock and live ocean data providers
    DesignSystem/                Color tokens, visual style helpers
    Domain/Models/               Beach, risk, layer, track models
    Domain/Prediction/           Particle model and coastline checks
    Features/BeachComparison/    Nearby beach comparison screen
    Features/BeachDetail/        Supporting detail panel components
    Features/MainMap/            Main map, sheets, markers, filters
    Resources/                   Assets, example API keys, coastline GeoJSON
    Shared/Utilities/            Location manager
  Jellyfish TrackerTests/        Prediction model tests
```

## Running The App

1. Open `Jellyfish Tracker/Jellyfish Tracker.xcodeproj` in Xcode.
2. Select the `Jellyfish Tracker` scheme.
3. Run on an iOS Simulator or device.

The app works without local credentials by using bundled reference data.

To enable live public data, copy the example key file:

```bash
cp "Jellyfish Tracker/Jellyfish Tracker/Resources/APIKeys.example.plist" \
   "Jellyfish Tracker/Jellyfish Tracker/Resources/APIKeys.plist"
```

Then fill any available keys:

```text
NIFS_API_KEY
TOUR_API_SERVICE_KEY
KMA_API_HUB_KEY
OCEAN_CURRENT_SERVICE_KEY
ROMS_SERVICE_KEY
TIDAL_CURRENT_SERVICE_KEY
```

`APIKeys.plist` is ignored by git. The same values can also be supplied through
environment variables. Optional endpoint overrides are supported for:

```text
OCEAN_CURRENT_ENDPOINT
ROMS_ENDPOINT
TIDAL_CURRENT_ENDPOINT
```

## Build And Test

Build for the iOS Simulator:

```bash
xcodebuild \
  -project "Jellyfish Tracker/Jellyfish Tracker.xcodeproj" \
  -scheme "Jellyfish Tracker" \
  -destination "generic/platform=iOS Simulator" \
  build
```

Run tests:

```bash
xcodebuild \
  -project "Jellyfish Tracker/Jellyfish Tracker.xcodeproj" \
  -scheme "Jellyfish Tracker" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  test
```

## Limitations

The current implementation is an MVP and should be read with these limits in
mind:

- NIFS observations are regional and approximate.
- Some public data sources update weekly or at coarse time intervals.
- Live coverage can be limited by API availability and coastal sensor coverage.
- Missing feeds may fall back to reference or persisted forcing data.
- Risk output is a planning aid, not an official safety warning.

## Next

- Real-time user jellyfish reporting
- Android expansion
- Jellyfish guide and first-response content
- Richer freshness and provenance indicators
- More complete coverage beyond the current Gyeongsangbuk-do MVP

## Team

**Team 35, Mokto Puzzle**

| Member | Role |
| --- | --- |
| Donghyeon An | Team Lead, Planning, Development |
| Minjae Son | Planning, Development |
| Minjae Kwon | Planning, Development |
| Subin Won | Planning, Design |

## References

- JunctionX Korea 2026 Team 35 VillyFish handoff deck
- NIFS jellyfish bulletin and public API
- KHOA ocean current, ROMS, tidal-current, and coastline data
- KMA marine observation and forecast data
- Korea Tourism Organization beach data
