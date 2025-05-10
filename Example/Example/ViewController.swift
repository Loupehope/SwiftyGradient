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

        let meshGradientView1 = MeshGradientView(width: 2, height: 5, colors: [
            UIColor(red: 255.0/255.0, green: 247.0/255.0, blue: 240.0/255.0, alpha: 1.0), UIColor(red: 255.0/255.0, green: 224.0/255.0, blue: 196.0/255.0, alpha: 1.0),
            UIColor(red: 254.0/255.0, green: 231.0/255.0, blue: 224.0/255.0, alpha: 1.0), UIColor(red: 255.0/255.0, green: 224.0/255.0, blue: 196.0/255.0, alpha: 1.0),
            UIColor(red: 249.0/255.0, green: 192.0/255.0, blue: 187.0/255.0, alpha: 1.0), UIColor(red: 241.0/255.0, green: 157.0/255.0, blue: 196.0/255.0, alpha: 1.0),
            UIColor(red: 246.0/255.0, green: 149.0/255.0, blue: 153.0/255.0, alpha: 1.0), UIColor(red: 249.0/255.0, green: 203.0/255.0, blue: 213.0/255.0, alpha: 1.0),
            UIColor(red: 249.0/255.0, green: 172.0/255.0, blue: 173.0/255.0, alpha: 1.0), UIColor(red: 254.0/255.0, green: 231.0/255.0, blue: 221.0/255.0, alpha: 1.0)
        ])!

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
