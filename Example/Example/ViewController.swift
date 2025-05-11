//
//  ViewController.swift
//  Example
//
//  Created by Vlad Suhomlinov on 08/05/2025.
//

import UIKit
import SwiftyGradient

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .tertiarySystemBackground

        let meshGradientView1 = MeshGradientView()!
        meshGradientView1.configure(
            MeshGradientView.MeshGradientViewModel(
                width: 2,
                height: 4,
                colors: [
                    UIColor(light: UIColor(hex: 0xE2F4FB), dark: UIColor(hex: 0x05212D)), UIColor(light: UIColor(hex: 0xE2F3FB), dark: UIColor(hex: 0x08232F)),
                    UIColor(light: UIColor(hex: 0xE2F3FB), dark: UIColor(hex: 0x082435)), UIColor(light: UIColor(hex: 0xD7E8FC), dark: UIColor(hex: 0x284361)),
                    UIColor(light: UIColor(hex: 0x9A99F4), dark: UIColor(hex: 0x072652)), UIColor(light: UIColor(hex: 0xCCDCFE), dark: UIColor(hex: 0x334C70)),
                    UIColor(light: UIColor(hex: 0xA5A7F5), dark: UIColor(hex: 0x062456)), UIColor(light: UIColor(hex: 0xD3E3FD), dark: UIColor(hex: 0x274463)),
                ]
            )
        )

        view.addSubview(meshGradientView1)

        meshGradientView1.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            meshGradientView1.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            meshGradientView1.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            meshGradientView1.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            meshGradientView1.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
        ])
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
