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

        let meshGradientView1 = MeshGradientView(width: 3, height: 3, bezierPoints: [
            .init(x: 0, y: 0), .init(x: 0.5, y: 0), .init(x: 1, y: 0),
            .init(x: 0, y: 0.5), .init(x: 0.5, y: 0.5), .init(x: 1, y: 0.5),
            .init(x: 0, y: 1), .init(x: 0.5, y: 1), .init(x: 1, y: 1)
        ], colors: [
            .systemRed, .systemPurple, .systemIndigo,
            .systemOrange, .white, .systemBlue,
            .systemYellow, .systemGreen, .systemMint
        ])!

        let meshGradientView2 = MeshGradientView(width: 2, height: 2, bezierPoints: [
            .init(x: 0, y: 0), .init(x: 1, y: 0),
            .init(x: 0, y: 1), .init(x: 1, y: 1)
        ], colors: [
            .systemIndigo, .systemCyan,
            .systemPurple, .systemPink
        ])!

        view.addSubview(meshGradientView1)
        view.addSubview(meshGradientView2)

        meshGradientView1.translatesAutoresizingMaskIntoConstraints = false
        meshGradientView2.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            meshGradientView1.widthAnchor.constraint(equalToConstant: 300),
            meshGradientView1.heightAnchor.constraint(equalTo: meshGradientView1.widthAnchor),
            meshGradientView1.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            meshGradientView1.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        NSLayoutConstraint.activate([
            meshGradientView2.widthAnchor.constraint(equalToConstant: 300),
            meshGradientView2.heightAnchor.constraint(equalTo: meshGradientView2.widthAnchor),
            meshGradientView2.topAnchor.constraint(equalTo: meshGradientView1.bottomAnchor, constant: 32),
            meshGradientView2.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
}
