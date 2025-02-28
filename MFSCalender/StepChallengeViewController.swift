//
//  StepChallengeViewController.swift
//  MFSMobile
//
//  Created by 戴元平 on 11/20/18.
//  Copyright © 2018 David. All rights reserved.
//

import UIKit
import SDWebImage
import HealthKit
import CRRefresh
import DZNEmptyDataSet
import SwiftDate

class StepChallengeViewController: UIViewController {
    var stepArray = [[String: Any]]()
    @IBOutlet var stepTable: UITableView!
    let stepChallenge = StepChallenge()
    @IBOutlet var pointLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.stepTable.delegate = self
        self.stepTable.dataSource = self
        stepTable.emptyDataSetSource = self
        stepTable.emptyDataSetDelegate = self
        
        let animator = RamotionAnimator(ballColor: UIColor.white, waveColor: UIColor.salmon)
        
        stepTable.cr.addHeadRefresh(animator: animator) { [weak self] in
            StepChallenge().reportSteps()
            self?.getSteps()
            self?.stepTable.cr.endHeaderRefresh()
        }
        
        if Preferences().isInStepChallenge {
            stepChallenge.reportSteps()
            getSteps()
            getPoints()
        }
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("History", comment: ""), style: .plain, target: self, action: #selector(history))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
    }
    
    @objc func history() {
        
    }
    
    func getSteps() {
        let region = Region(zone: TimeZone(identifier: "America/New_York")!)
        let date = DateInRegion.init(Date(), region: region)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let checkDate = formatter.string(from: date.date)
        
        provider.request(MyService.getSteps(date: checkDate), callbackQueue: DispatchQueue.global()) { (result) in
            switch result {
            case .success(let response):
                do {
                    guard let json = try JSONSerialization.jsonObject(with: response.data, options: .allowFragments) as? [[String: Any]] else {
                        print("Failed to construct json object.")
                        return
                    }
                    
                    self.stepArray = json
                    print(json)
                    self.sortSteps()
                } catch {
                    print(error.localizedDescription)
                }
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    func getPoints() {
        let preferences = Preferences()
        let currentUserName = (preferences.firstName ?? "") + " " + (preferences.lastName ?? "")
        provider.request(MyService.getStepPoints(username: currentUserName), callbackQueue: DispatchQueue.global()) { (result) in
            switch result {
            case .success(let response):
                let totalPoints = String.init(data: response.data, encoding: .utf8) ?? ""
//                print(response.request?.url)
                DispatchQueue.main.async {
                    self.pointLabel.text = totalPoints
                }
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func sortSteps() {
        stepArray = stepArray.sorted(by: { (first, second) -> Bool in
            let firstStep = first["steps"] as? Int ?? 0
            let secondStep = second["steps"] as? Int ?? 0
            return  firstStep>secondStep
        })
        
        DispatchQueue.main.async {
            self.stepTable.reloadData()
        }
    }
}

extension StepChallengeViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        if Preferences().isInStepChallenge {
            return 2
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
            return stepArray.count;
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var stepRecord = [String: Any]()
        let preferences = Preferences()
        let currentUserName = (preferences.firstName ?? "") + " " + (preferences.lastName ?? "")
        
        if indexPath.section == 0 {
            stepRecord = stepArray.filter({ (object) -> Bool in
                return (object["name"] as? String ?? "") == currentUserName
            }).first ?? [String: Any]()
        } else {
            stepRecord = stepArray[indexPath.row]
        }
        let cell = stepTable.dequeueReusableCell(withIdentifier: "stepRecord", for: indexPath) as! StepTableCell
        
        cell.name.text = stepRecord["name"] as? String ?? ""
        cell.rank.text = String(indexPath.row + 1)
        cell.steps.text = String(stepRecord["steps"] as? Int ?? 0)
        let photoLink = stepRecord["link"] as? String ?? ""
        let photoURL = URL(string: Preferences().baseURL + photoLink)
        cell.photo.sd_setImage(with: photoURL, completed: nil)
        cell.photo.contentMode = .scaleAspectFill
        return cell
    }
}

extension StepChallengeViewController: DZNEmptyDataSetSource, DZNEmptyDataSetDelegate {
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        var str: String? = ""
        let attrs: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)]
        str = NSLocalizedString("Join Step Challenge!", comment: "")
        
        return NSAttributedString(string: str!, attributes: attrs)
    }
    
    func image(forEmptyDataSet scrollView: UIScrollView!) -> UIImage! {
        let image: UIImage = UIImage(named: "runningColor.png")!.imageResize(sizeChange: CGSize(width: 100, height: 100))
        return image
    }
    
    func buttonTitle(forEmptyDataSet scrollView: UIScrollView!, for state: UIControl.State) -> NSAttributedString! {
        let str: String = NSLocalizedString("Join", comment: "")
        let attrs: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)]
        
        return NSAttributedString(string: str, attributes: attrs)
    }
    
    func emptyDataSet(_ scrollView: UIScrollView!, didTap button: UIButton!) {
        Preferences().isInStepChallenge = true
        viewDidLoad()
    }
}

class StepChallenge {
    let healthManager: HealthKitManager = HealthKitManager()
    let healthStore = HKHealthStore()
    
    func getTodaysSteps(completion: @escaping (Double) -> Void) {
        let stepsQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepsQuantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(0.0)
                return
            }
            completion(sum.doubleValue(for: HKUnit.count()))
        }
        
        healthStore.execute(query)
    }
    
    func uploadResult(steps: String) {
        let preferences = Preferences()
        let username = (preferences.firstName ?? "") + " " + (preferences.lastName ?? "")
        let link = (preferences.photoLink ?? "none")
        provider.request(MyService.reportSteps(steps: steps, username: username, link: link)) { (result) in
            switch result {
            case .success(_):
                print("Successfully uploaded the result")
                break
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    func reportSteps() {
        // 在 HealthKitManager.swift 文件里寻找授权情况。
        healthManager.authorizeHealthKit { (authorized,  error) -> Void in
            if authorized {
                // Great!
                self.getTodaysSteps { (steps) in
                    let stepsString = String(Int(steps))
                    self.uploadResult(steps: stepsString)
                }
            } else {
                if error != nil {
                    print(error as Any)
                }
                print("Permission denied.")
            }
        }
    }
}

class HealthKitManager {
    let healthKitStore: HKHealthStore = HKHealthStore()
    
    func authorizeHealthKit(completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        
        // 声明我们想从 HealthKit 里读取的健康数据的类型
        let healthDataToRead = Set(arrayLiteral: HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!)
        
        if !HKHealthStore.isHealthDataAvailable() {
            print("Can't access HealthKit.")
        }
        
        // 请求可以读取数据的权限
        healthKitStore.requestAuthorization(toShare: nil, read: healthDataToRead) { (success, error) -> Void in
                completion(success, error)
        }
    }
}

class StepTableCell: UITableViewCell {
    @IBOutlet var rank: UILabel!
    @IBOutlet var photo: UIImageView!
    @IBOutlet var name: UILabel!
    @IBOutlet var steps: UILabel!
}
