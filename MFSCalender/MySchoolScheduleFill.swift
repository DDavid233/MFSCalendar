//
//  MyMFSScheduleFill.swift
//  MFSMobile
//
//  Created by David on 2/20/18.
//  Copyright © 2018 David. All rights reserved.
//

import Foundation
import SwiftDate
import CoreData

class MySchoolScheduleFill {
    let courseListPath = URL.init(fileURLWithPath: userDocumentPath.appending("/CourseList.plist"))
    var courseList: [[String: Any]]
    
    init() {
        courseList = NSArray(contentsOf: courseListPath) as? [[String: Any]] ?? [[String: Any]]()
    }
    
    func getScheduleFromMySchool(startTime: Date, endTime: Date) -> [[String: Any]] {
        let semaphore = DispatchSemaphore.init(value: 0)
        let userID = Preferences().userID ?? "0"
        let startTimeStamp = Int(startTime.timeIntervalSince1970)
        let endTimeStamp = Int(endTime.timeIntervalSince1970)
        var dictToReturn = [[String: Any]]()
        
        provider.request(MyService.mySchoolGetSchedule(startTimeStamp: String(startTimeStamp), endTimeStamp: String(endTimeStamp), userID: userID), callbackQueue: DispatchQueue.global()) { (result) in
            switch result {
            case let .success(response):
                do {
                    guard let json = try JSONSerialization.jsonObject(with: response.data, options: .allowFragments) as? [[String: Any]] else {
                        presentErrorMessage(presentMessage: "JSON file has incorrect format.", layout: .statusLine)
                        return
                    }
                    
                    dictToReturn = json
                } catch {
                    presentErrorMessage(presentMessage: error.localizedDescription, layout: .statusLine)
                }
            case let .failure(error):
                print(error.localizedDescription)
            }
            
            semaphore.signal()
        }
        
        semaphore.wait()
        return dictToReturn
    }
    
    func storeMySchoolSchedule(scheduleData: [[String: Any]]) {
        for course in scheduleData {
            var course = course
            let keysToRemove = course.keys.filter {
                guard let value = course[$0] else { return false }
                return (value as? NSNull) == NSNull()
            }
            
            for key in keysToRemove {
                course.removeValue(forKey: key)
            }
            
            if (course["allDay"] as? Bool ?? true) {
                writeDayDataToFile(course: course)
            } else {
                writeScheduleDataToFile(course: course)
            }
        }
        
        do {
            try managedContext?.save()
        } catch {
            fatalError("Failure to save context: \(error)")
        }
    }
    
    func writeDayDataToFile(course: [String: Any]) {
        guard let startDate = course["start"] as? String else {
            print("writeDayDataToFile: StartTimeNotFound")
            return
        }
        
        guard let dateString = dateStringFormatter(date: startDate) else {
            return
        }
        
        guard let dayDescription = course["title"] as? String else {
            print("writeDayDataToFile: Title not found")
            return
        }
        
        let abbreviation = abbreviateTitle(title: dayDescription)
        
        let dayDictPath = userDocumentPath.appending("/Day.plist")
        var dayDict = NSDictionary(contentsOfFile: dayDictPath) as? [String: String] ?? [String: String]()
        
        dayDict[dateString] = abbreviation
        NSDictionary(dictionary: dayDict).write(toFile: dateString, atomically: true)
    }
    
    func writeScheduleDataToFile(course: [String: Any]) {
        let courseObject = NSEntityDescription.insertNewObject(forEntityName: "Course", into: managedContext!) as! CourseMO

        guard let startString = course["start"] as? String else {
            print("writeScheduleDataToFile: StartDateNotFound")
            return
        }
        guard let start = timeStringFormatter(date: startString) else {
            return
        }
        courseObject.startTime = start
        
        guard let endString = course["end"] as? String else {
            print("writeScheduleDataToFile: EndDateNotFound")
            return
        }
        guard let end = timeStringFormatter(date: endString) else {
            return
        }
        courseObject.endTime = end
        
        let title = course["title"] as? String ?? ""
        courseObject.name = title
        
        if let courseInList = courseList
                             .filter({ $0["sectionidentifier"] as? String == title })
                             .first {
            courseObject.secionID = Int32(courseInList["sectionid"] as? Int ?? 0)
            courseObject.room = "" //TODO: Add room number
        }
        
    }
    
    func timeStringFormatter(date: String) -> Date? {
        guard let date = DateInRegion(string: date, format: .custom("M/d/yyyy h:mm a")) else {
            presentErrorMessage(presentMessage: "dateStringFormatter: Date cannot be converted", layout: .statusLine)
            return nil
        }
        
        return date.absoluteDate
    }
    
    func dateStringFormatter(date: String) -> String? {
        guard let date = DateInRegion(string: date, format: .custom("M/d/yyyy h:mm a")) else {
            presentErrorMessage(presentMessage: "dateStringFormatter: Date cannot be converted", layout: .statusLine)
            return nil
        }
        
        let dateString = date.string(format: .custom("yyyyMMdd"))
        return dateString
    }
    
    func abbreviateTitle(title: String) -> String {
        var abbreviation = ""
        let components = title.components(separatedBy: [" ", "-"])
        if components.contains("Late") {
            abbreviation = "Late"
        } else if components.contains("Mass") {
            abbreviation = "Mass"
        }
        
        if let letter = components.filter({ $0.count == 1 }).first {
            abbreviation += letter
        }
        
        return abbreviation
    }
}


