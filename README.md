# Telescope

[![Documentation](https://github.com/persello/telescope/actions/workflows/documentation.yml/badge.svg)](https://github.com/persello/telescope/actions/workflows/documentation.yml) [![Swift](https://github.com/persello/telescope/actions/workflows/swift.yml/badge.svg)](https://github.com/persello/telescope/actions/workflows/swift.yml)

A double-cached (NSCache and local files) web image library for SwiftUI.

For API documentation, check the [Wiki](https://github.com/persello/telescope/wiki).

## Examples

### Using an image as a SwiftUI View

```Swift
TImage(try? RemoteImage(stringURL: "https://picsum.photos/800/800"))
    .resizable()
    .scaledToFit()
    .frame(width: 800, height: 1200, alignment: .center)
```

![Preview Screenshot](Resources/ss1.png=250x)
