//
//  ClassPagerViewController.swift
//  MFSCalendar
//
//  Created by David Dai on 2017/7/2.
//  Copyright © 2017 David. All rights reserved.
//

import UIKit
import XLPagerTabStrip

class classPagerViewController: ButtonBarPagerTabStripViewController, UIDocumentInteractionControllerDelegate {
    

    override func viewDidLoad() {
        settings.style.buttonBarMinimumLineSpacing = 0
        settings.style.buttonBarItemBackgroundColor = UIColor(hexString: 0xFF7E79)
        settings.style.buttonBarItemFont = .boldSystemFont(ofSize: 14)
        settings.style.buttonBarItemsShouldFillAvailableWidth = true
        settings.style.buttonBarItemTitleColor = .white
        settings.style.selectedBarBackgroundColor = .white
        settings.style.selectedBarHeight = 5

        changeCurrentIndexProgressive = { (oldCell: ButtonBarViewCell?, newCell: ButtonBarViewCell?, progressPercentage: CGFloat, changeCurrentIndex: Bool, animated: Bool) -> Void in
            guard changeCurrentIndex == true else {
                return
            }
            oldCell?.label.textColor = .white
            newCell?.label.textColor = .white
        }

//        Important: Settings should be called before viewDidLoad is called.
        super.viewDidLoad()

        let classObject = ClassView().getTheClassToPresent() ?? [String: Any]()
        self.title = classObject["className"] as? String

        self.navigationController?.navigationBar.barTintColor = UIColor(hexString: 0xFF7E79)
        self.navigationController?.navigationBar.isTranslucent = false
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
    }

    override func viewControllers(for pagerTabStripController: PagerTabStripViewController) -> [UIViewController] {

        let overviewViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "overview")
        let topicViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "topic")
        let gradeViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "gradeViewController")
        return [overviewViewController, topicViewController, gradeViewController]
    }

    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
}
