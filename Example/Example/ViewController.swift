//
//  ViewController.swift
//  Example
//
//  Created by Vlad Suhomlinov on 08/05/2025.
//

import UIKit
import SwiftyGradient

class ViewController: UIViewController {
    let swiftyGradientView = MeshGradientViewV2()!

    lazy var displaylink = CADisplayLink(target: self, selector: #selector(test(_:)))
    let colors = [
        UIColor(light: UIColor(hex: 0xE2F4FB), dark: UIColor(hex: 0x05212D)), UIColor(light: UIColor(hex: 0xE2F3FB), dark: UIColor(hex: 0x08232F)),
        UIColor(light: UIColor(hex: 0xE2F3FB), dark: UIColor(hex: 0x082435)), UIColor(light: UIColor(hex: 0xD7E8FC), dark: UIColor(hex: 0x284361)),
        UIColor(light: UIColor(hex: 0x9A99F4), dark: UIColor(hex: 0x072652)), UIColor(light: UIColor(hex: 0xCCDCFE), dark: UIColor(hex: 0x334C70)),
        UIColor(light: UIColor(hex: 0xA5A7F5), dark: UIColor(hex: 0x062456)), UIColor(light: UIColor(hex: 0xD3E3FD), dark: UIColor(hex: 0x274463))
    ]
    @objc
    func test(_ s: CADisplayLink) {
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            let new = self.animatedColors(colors: self.colors, for: Date())
            
            DispatchQueue.main.async {
                self.swiftyGradientView.configure(width: 2, height: 4, colors: new)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .tertiarySystemBackground

        
//        swiftyGradientView.configure(width: 2, height: 4, colors: [
//            UIColor(light: UIColor(hex: 0xE2F4FB), dark: UIColor(hex: 0x05212D)), UIColor(light: UIColor(hex: 0xE2F3FB), dark: UIColor(hex: 0x08232F)),
//            UIColor(light: UIColor(hex: 0xE2F3FB), dark: UIColor(hex: 0x082435)), UIColor(light: UIColor(hex: 0xD7E8FC), dark: UIColor(hex: 0x284361)),
//            UIColor(light: UIColor(hex: 0x9A99F4), dark: UIColor(hex: 0x072652)), UIColor(light: UIColor(hex: 0xCCDCFE), dark: UIColor(hex: 0x334C70)),
//            UIColor(light: UIColor(hex: 0xA5A7F5), dark: UIColor(hex: 0x062456)), UIColor(light: UIColor(hex: 0xD3E3FD), dark: UIColor(hex: 0x274463))
//        ])
        
        

        view.addSubview(swiftyGradientView)

        swiftyGradientView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            swiftyGradientView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            swiftyGradientView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            swiftyGradientView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            swiftyGradientView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
        
        swiftyGradientView.configure(width: 2, height: 4, colors: colors)
        displaylink.add(to: .main, forMode: .common)
    }
    
    private func animatedColors(colors: [UIColor], for date: Date) -> [UIColor] {
        let phase = CGFloat(date.timeIntervalSince1970)
        
        return colors.enumerated().map { index, color in
            let hueShift = cos(phase + Double(index) * 0.3) * 0.1
            return shiftHue(of: color, by: hueShift)
        }
    }
    
    private func shiftHue(of color: UIColor, by amount: Double) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        hue += CGFloat(amount)
        hue = hue.truncatingRemainder(dividingBy: 1.0)
        
        if hue < 0 {
            hue += 1
        }
        
        return UIColor(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness), alpha: Double(alpha))
    }

}

extension UIColor {
    convenience init(
        light lightModeColor: @escaping @autoclosure () -> UIColor,
        dark darkModeColor: @escaping @autoclosure () -> UIColor
     ) {
        self.init { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .light:
                return lightModeColor()

            case .dark:
                return darkModeColor()

            case .unspecified:
                return lightModeColor()
            @unknown default:
                return lightModeColor()
            }
        }
    }
}

extension UIColor {
   convenience init(red: Int, green: Int, blue: Int) {
       assert(red >= 0 && red <= 255, "Invalid red component")
       assert(green >= 0 && green <= 255, "Invalid green component")
       assert(blue >= 0 && blue <= 255, "Invalid blue component")

       self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
   }

   convenience init(hex: Int) {
       self.init(
           red: (hex >> 16) & 0xFF,
           green: (hex >> 8) & 0xFF,
           blue: hex & 0xFF
       )
   }
}
