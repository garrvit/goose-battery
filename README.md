# GooseBattery

Realtime macOS battery dashboard showing:

- charging speed in `mAh/h`
- battery consumption in `mAh/h`
- battery health from full-charge vs design capacity
- filled and empty charge in raw `mAh`
- adapter wattage and live battery power

## Build

```bash
cd /Users/garvit/Downloads/goose/GooseBattery
xcodegen generate
xcodebuild -project GooseBattery.xcodeproj -scheme GooseBattery -configuration Debug -derivedDataPath Build build
```

## Data source

The app reads the `AppleSmartBattery` IORegistry service directly and derives:

- charging speed: positive live battery current
- consumption: negative live battery current converted to a positive rate
- filled mAh: `AppleRawCurrentCapacity`
- empty mAh: `AppleRawMaxCapacity - AppleRawCurrentCapacity`
- health: `AppleRawMaxCapacity / DesignCapacity`

On some Macs, `system_profiler SPPowerDataType | grep "Wattage"` returns nothing. In that case the app falls back to adapter details exposed by the battery service itself, which is what this Mac reports.
