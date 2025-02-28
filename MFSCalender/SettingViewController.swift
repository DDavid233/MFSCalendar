//
//  settingViewController.swift
//  MFSCalendar
//
//  Created by David Dai on 2017/6/22.
//  Copyright © 2017 David. All rights reserved.
//

import UIKit

class settingViewController: UITableViewController, UIActionSheetDelegate {
    @IBOutlet var currentQuarter: UISegmentedControl!
    @IBOutlet var quarterLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSegmentedControl()
    }
    
    func setupSegmentedControl() {
        let quarterScheduleListPath = FileList.quarterSchedule.filePath
        if let quarterSchedule = NSArray(contentsOfFile: quarterScheduleListPath) as? [[String: Any]] {
            currentQuarter.removeAllSegments()
            for (index, quarterDict) in quarterSchedule.enumerated() {
                let description = (quarterDict["DurationDescription"] as? String ?? "")[0, 2]
                currentQuarter.insertSegment(withTitle: description, at: index, animated: false)
            }
            
            currentQuarter.selectedSegmentIndex = Preferences().currentQuarter - 1
        }
        
    }

    override func viewWillAppear(_ animated: Bool) {
//        themeColorLabel.text = userDefaults?.string(forKey: "themeColor") ?? "Salmon"
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        if indexPath.section == 0 {
//            let logOutActionSheet = UIAlertController(title: nil, message: "Select one theme color.", preferredStyle: .actionSheet)
//
//            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (alertAction) -> Void in
//                NSLog("Canceled")
//            }
//
//            let salmonAction = UIAlertAction(title: "Salmon", style: .default) { (alertAction) -> Void in
//
//                let vc = self.storyboard?.instantiateViewController(withIdentifier: "MainTab")
//                self.present(vc!, animated: false, completion: nil)
//            }
//
////            let indigoAction = UIAlertAction(title: "Indigo", style: .default) { (alertAction) -> Void in
////                let vc = self.storyboard?.instantiateViewController(withIdentifier: "MainTab")
////                self.present(vc!, animated: false, completion: nil)
////            }
//
//            logOutActionSheet.addAction(cancelAction)
//            logOutActionSheet.addAction(salmonAction)
//            
//            logOutActionSheet.popoverPresentationController?.sourceView = self.view
//            logOutActionSheet.popoverPresentationController?.sourceRect = self.view.bounds
//
//            self.present(logOutActionSheet, animated: true, completion: nil)
//        }
        
    }
    
    @IBAction func changeQuarter(_ sender: Any) {
        let quarterActionSheet = UIAlertController(title: NSLocalizedString("Are you sure you want to change quarter?", comment: ""), message: NSLocalizedString("This will clear all the course data.", comment: ""), preferredStyle: .actionSheet)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { (alertAction) -> Void in
            NSLog("Canceled")
        }
        
        let changeQuarterAction = UIAlertAction(title: NSLocalizedString("Yes, change it!", comment: ""), style: .default) { (alertAction) -> Void in
            print(self.currentQuarter.selectedSegmentIndex)
            self.changeQuarterTo(quarter: self.currentQuarter.selectedSegmentIndex + 1)
            NSLog("Quarter Changed")
        }
        
        quarterActionSheet.addAction(cancelAction)
        quarterActionSheet.addAction(changeQuarterAction)
        
        if let segmentedView = sender as? UIView {
            quarterActionSheet.popoverPresentationController?.sourceView = segmentedView
            quarterActionSheet.popoverPresentationController?.sourceRect = segmentedView.frame
        }
        
        self.present(quarterActionSheet, animated: true, completion: nil)
    }
    
    func changeQuarterTo(quarter: Int) {
        Preferences().currentQuarter = quarter
        let quarterScheduleListPath = FileList.quarterSchedule.filePath
        if let quarterSchedule = NSArray(contentsOfFile: quarterScheduleListPath) as? [[String: Any]] {
            if quarterSchedule.count >= quarter {
                Preferences().durationID = String(quarterSchedule[quarter - 1]["DurationId"] as? Int ?? 0)
                Preferences().durationDescription = quarterSchedule[quarter - 1]["DurationDescription"] as? String
            }
        }
        
        Preferences().courseInitialized = false
        Preferences().doUpdateQuarter = false
        self.tabBarController?.selectedIndex = 0
    }
}
