# SwiftyGradient

## MeshGradient

Аналог MeshGradient для SwiftUI - https://developer.apple.com/documentation/SwiftUI/MeshGradient

### Пример использования

```swift
let meshGradientView = MeshGradientView(width: 3, height: 3, colors: [
    .systemRed, .systemPurple, .systemIndigo,
    .systemOrange, .white, .systemBlue,
    .systemYellow, .systemGreen, .systemMint
])

// ----

let meshGradientView2 = MeshGradientView(width: 2, height: 2, colors: [
    .systemIndigo, .systemCyan,
    .systemPurple, .systemPink
])
```

![Результат](./Resources/Example.png){width=50%}

## Скрипты

Линтер - `./Scripts/lint.sh`
