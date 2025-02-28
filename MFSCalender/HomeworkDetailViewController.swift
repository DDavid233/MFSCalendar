//
//  HomeworkDetailViewController.swift
//  MFSCalendar
//
//  Created by David Dai on 2017/9/8.
//  Copyright © 2017 David. All rights reserved.
//

import UIKit
import M13Checkbox
import SafariServices
import SVProgressHUD
import WidgetKit

class homeworKDetailViewController: UIViewController, SFSafariViewControllerDelegate, UIDocumentInteractionControllerDelegate {
    
    @IBOutlet var tableView: UITableView!
    
    var headerList = ["Detail"]
    var contentList = [[String: Any]]()
    var assignmentList2 = [String: Any]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 11.0, *) {
            disableLargeTitle(on: self)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        DispatchQueue.global().async {
            self.getContents()
        }
    }
    
    func getContents() {
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            SVProgressHUD.show()
        }
        
        let group = DispatchGroup()
        
        DispatchQueue.global().async(group: group) {
            self.getTheHomeworkToPresent()
        }
        
        DispatchQueue.global().async(group: group) {
            self.getLinksToPresent()
        }
        
        group.wait()
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            SVProgressHUD.dismiss()
        }
    }
    
    func getTheHomeworkToPresent() {
        let assignmentIndexID = Preferences().indexIdForAssignmentToPresent
        
        let (success, _, userId) = loginAuthentication()
        
        guard success else {
            return
        }
        
        let url = URL(string: Preferences().baseURL + "/api/datadirect/AssignmentStudentDetail?format=json&studentId=\(userId)&AssignmentIndexId=\(assignmentIndexID)")!
        print(url)
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
            guard error == nil else {
                presentErrorMessage(presentMessage: error!.localizedDescription, layout: .cardView)
                semaphore.signal()
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [[String: Any]] {
                    self.contentList = json
                }
            } catch {
                presentErrorMessage(presentMessage: error.localizedDescription, layout: .cardView)
            }
            semaphore.signal()
        })
        
        task.resume()
        semaphore.wait()
    }
    
    func getLinksToPresent() {
        let assignmentID = Preferences().idForAssignmentToPresent
        
        let url = Preferences().baseURL + "/api/assignment2/read/\(String(describing: assignmentID))/?format=json"
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = URLSession.shared.dataTask(with: URL(string: url)!, completionHandler: { (data, response, error) in
            guard error == nil else {
                presentErrorMessage(presentMessage: error!.localizedDescription, layout: .cardView)
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String: Any] else {
                    presentErrorMessage(presentMessage: "Incorrect file format", layout: .statusLine)
                    return
                }
                
                self.assignmentList2 = json
            } catch {
                presentErrorMessage(presentMessage: error.localizedDescription, layout: .statusLine)
            }
            
            semaphore.signal()
        })
        
        task.resume()
        semaphore.wait()
        checkIfLinksAndDownloadsExists()
    }
    
    func checkIfLinksAndDownloadsExists() {
        headerList = ["Detail"]
        
        if let linkList = assignmentList2["LinkItems"] as? [[String: Any]] {
            if !linkList.isEmpty {
                headerList.append("Links")
            }
        }
        
        if let downloadList = assignmentList2["DownloadItems"] as? [[String: Any]] {
            if !downloadList.isEmpty {
                headerList.append("Downloads")
            }
        }
    }
    
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
}

extension homeworKDetailViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return headerList.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch headerList[section] {
        case "Detail":
            return 2
        case "Links":
            return (assignmentList2["LinkItems"] as? [[String: Any]])?.count ?? 0
        case "Downloads":
            return (assignmentList2["DownloadItems"] as? [[String: Any]])?.count ?? 0
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch headerList[indexPath.section] {
        case "Detail":
            guard indexPath.row == 0 else {
                return
            }
            
            let courseListPath = FileList.courseList.filePath
            guard let courseList = NSArray(contentsOfFile: courseListPath) as? [[String: Any]] else {
                return
            }
            
            guard !contentList.isEmpty else {
                return
            }
            
            guard let courseName = contentList[0]["sectionName"] as? String else {
                return
            }
            
            guard let index = courseList.firstIndex(where: { ($0["className"] as? String) == courseName }) else {
                presentErrorMessage(presentMessage: "Course not found", layout: .statusLine)
                return
            }
            
            Preferences().indexForCourseToPresent = index
            
            let classDetailViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "classDetailViewController")
            self.show(classDetailViewController, sender: self)
        case "Links":
            openLink(row: indexPath.row)
        case "Downloads":
            openFile(row: indexPath.row)
        default:
            return
        }
    }
    
    func openLink(row: Int) {
        guard  let linkList = assignmentList2["LinkItems"] as? [[String: Any]]  else {
            return
        }
        
        guard linkList.indices.contains(row) else {
            return
        }
        
        guard let link = linkList[row]["Url"] as? String else {
            return
        }
        
        let safari = SFSafariViewController(url: URL(string: link)!)
        safari.delegate = self
        present(safari, animated: true, completion: nil)
    }
    
    func openFile(row: Int) {
        let noAttachmentFound = NSLocalizedString("No attachment is found.", comment: "")
        guard let downloadList = assignmentList2["DownloadItems"] as? [[String: Any]] else {
            presentErrorMessage(presentMessage: noAttachmentFound, layout: .statusLine)
            return
        }
        
        guard downloadList.indices.contains(row) else {
            presentErrorMessage(presentMessage: noAttachmentFound, layout: .statusLine)
            return
        }
        
        let downloadObject = downloadList[row]
        
        guard let url = downloadObject["DownloadUrl"] as? String, let fileName = downloadObject["FriendlyFileName"] as? String else {
            presentErrorMessage(presentMessage: noAttachmentFound, layout: .statusLine)
            return
        }
        
        let downloadUrl = URL(string: Preferences().baseURL + url)!
        let (filePath, error) = NetworkOperations().downloadFile(url: downloadUrl, withName: fileName)
        
        guard error == nil else {
            presentErrorMessage(presentMessage: error!.localizedDescription, layout: .statusLine)
            return
        }
        
        guard filePath != nil else {
            presentErrorMessage(presentMessage: NSLocalizedString("Attachment cannot be downloaded", comment: ""), layout: .statusLine)
            return
        }
        
        NetworkOperations().openFile(fileUrl: filePath!, from: self)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch headerList[indexPath.section] {
        case "Detail":
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "simpleCell", for: indexPath)
                if contentList.count > 0 {
                    cell.textLabel?.text = contentList[0]["sectionName"] as? String
                }
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "homeworkDetailViewCell", for: indexPath) as! homeworkDetailViewCell
                guard contentList.count > 0 else { return cell }
                let contentObject = contentList[0]
                
                let assignmentIndexID = Preferences().indexIdForAssignmentToPresent
                cell.assignmentIndexID = String(describing: assignmentIndexID)
                
                
                if let shortDescription = (contentObject["title"] as? String ?? "").convertToHtml(isTitle: true) {
                    cell.title.attributedText = shortDescription
                }
                
                let longDescription = contentObject["description"] as? String ?? ""
                if let attributedText = longDescription.convertToHtml() {
                    cell.textView.attributedText = attributedText
                }
                
                if let assigmentStatus = contentObject["assignmentStatus"] as? Int {
                    let checkState = HomeworkView().checkStateFor(status: assigmentStatus)
                    cell.checkBox.setCheckState(checkState, animated: true)
                }
                
                let assignmentType = contentObject["assignmentType"] as? String ?? ""
                cell.checkBox.tintColor = HomeworkView().colorForTheType(type: assignmentType)
                
                cell.selectionStyle = .none
                
                return cell
            }
        case "Links":
            let cell = tableView.dequeueReusableCell(withIdentifier: "simpleCell", for: indexPath)
            guard let linkList = assignmentList2["LinkItems"] as? [[String: Any]] else {
                return cell
            }
            
            guard linkList.count >= indexPath.row + 1 else { return cell }
            let linkObject = linkList[indexPath.row]
            
            cell.textLabel?.text = linkObject["ShortDescription"] as? String
            
            cell.selectionStyle = .default
            
            return cell
        case "Downloads":
            let cell = tableView.dequeueReusableCell(withIdentifier: "simpleCell", for: indexPath)
            guard let downloadList = assignmentList2["DownloadItems"] as? [[String: Any]] else {
                return cell
            }
            
            guard downloadList.count >= indexPath.row + 1 else { return cell }
            let downloadObject = downloadList[indexPath.row]

            cell.textLabel?.text = downloadObject["ShortDescription"] as? String
            
            cell.selectionStyle = .default
            
            return cell
        default:
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200
    }
}

class homeworkDetailViewCell: UITableViewCell {
    @IBOutlet var title: UILabel!
    @IBOutlet var textView: UITextView!
    @IBOutlet var checkBox: M13Checkbox!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    
    var assignmentIndexID: String? = nil
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        textView.isEditable = false
        activityIndicator.isHidden = true
        checkBox.stateChangeAnimation = .bounce(.fill)
        checkBox.boxLineWidth = 3
        checkBox.addTarget(self, action: #selector(checkDidChange), for: UIControl.Event.valueChanged)
    }
    
    @objc func checkDidChange() {
        if #available(iOS 10.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        }
        DispatchQueue.global().async {
            guard loginAuthentication().success else {
                return
            }
            guard (self.assignmentIndexID != nil) else {
                return
            }
            
            var assignmentStatus: String? = nil
            switch self.checkBox.checkState {
            case .checked:
                assignmentStatus = "1"
            case .unchecked:
                assignmentStatus = "-1"
            default:
                NSLog("Something strange happened.")
                return
            }
            
            DispatchQueue.main.async {
                self.activityIndicator.isHidden = false
                self.activityIndicator.startAnimating()
            }
            
            do {
                try HomeworkView().updateAssignmentStatus(assignmentIndexId: self.assignmentIndexID!, assignmentStatus: assignmentStatus!)
            } catch {
                switch self.checkBox.checkState {
                case .checked:
                    self.checkBox.setCheckState(.unchecked, animated: false)
                case .unchecked:
                    self.checkBox.setCheckState(.checked, animated: false)
                default:
                    break
                }
            }
            
            DispatchQueue.main.async {
                if #available(iOS 14.0, *) {
                    WidgetCenter.shared.reloadAllTimelines()
                }
                self.activityIndicator.isHidden = true
                self.activityIndicator.stopAnimating()
            }
        }
    }
}

