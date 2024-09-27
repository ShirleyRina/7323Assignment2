//
//  ViewController.swift
//  7323Assignment2
//
//  Created by shirley on 9/27/24.
//

import UIKit

class LandingViewController: UIViewController {
   
    @IBAction func goToModuleA(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let moduleAViewController = storyboard.instantiateViewController(withIdentifier: "ModuleAViewController") as? ModuleAViewController {
            self.navigationController?.pushViewController(moduleAViewController, animated: true)
        }
    }
    
    @IBAction func goToModuleB(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let moduleBViewController = storyboard.instantiateViewController(withIdentifier: "ModuleBViewController") as? ModuleBViewController {
            self.navigationController?.pushViewController(moduleBViewController, animated: true)
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }


}

