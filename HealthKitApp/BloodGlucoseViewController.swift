//
//  BloodGlucoseViewController.swift
//  HealthKitApp
//
//  Created by Ted Rogers on 7/1/14.
//  Copyright (c) 2014 Ted Rogers Consulting, LLC. All rights reserved.
//

import UIKit
import HealthKit

class BloodGlucoseViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    let bloodGlucoseUnitString = "mg/dL"
    let bloodGlucoseUnit = HKUnit(from: "mg/dL") // or HKUnit.countUnit().unitDividedByUnit(HKUnit.minuteUnit())
    // blood glucose metadata meal
    let myHKMetadataKeyBloodGlucoseWhen = "com.tedmrogers.HealthKitApp.When"
    let myHKMetadataValueBloodGlucoseWhenMorning = "Morning"
    let myHKMetadataValueBloodGlucoseWhenPreMeal = "Pre-Meal"
    let myHKMetadataValueBloodGlucoseWhenPostMeal = "Post-Meal"
    let myHKMetadataValueBloodGlucoseWhenNight = "Night"
    // blood glucose metadata notes
    let myHKMetadataKeyBloodGlucoseNotes = "com.tedmrogers.HealthKitApp.Notes"
    let kBloodGlucoseCellIdentifier = "BloodGlucoseIdentifier"

    // the list of glucose samples
    var bloodGlucoseSamples:[AnyObject]?   // optional
    var dateFormatter:DateFormatter!     // implicitly unwrapped optional - use these when they should never be null after initialization
    
    // MARK: Outlets
    @IBOutlet var tableView: UITableView!
    
    override func viewDidLoad() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        // check for presence of HealthKit with optional binding statement
        if let healthStore = appDelegate.healthStore {
            self.initHealthKit(healthStore: healthStore)
        } else {
            // wait for notifiication that HealthKit is ready
            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: Constants.kHealthKitInitialized), object: nil, queue: nil) { (notif: Notification!) -> Void in
                // make no assumptions about current queue
                DispatchQueue.main.async {
                    self.initHealthKit(healthStore: appDelegate.healthStore!)
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        print("tableView height = \(tableView.frame.height)")
    }
    
    // MARK: Implementation
    
    func initHealthKit(healthStore: HKHealthStore) {
        // now let's go get the latest heart rate sample - use the end date and get in reverse chronological order
        let endDate = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let sortDescriptors = [endDate]
        let bloodGlucoseType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)
        // build up sampple query
        let sampleQuery = HKSampleQuery(sampleType: bloodGlucoseType!, predicate: nil, limit: Int(HKObjectQueryNoLimit), sortDescriptors: sortDescriptors) { // trailing closure
            (query: HKSampleQuery, querySamples: [HKSample]?, error: Error?) in
            if let myError = error {
                print("sample query returned error = \(myError)")
            } else if let samples = querySamples, samples.count > 0 {
                DispatchQueue.main.async {
                    self.bloodGlucoseSamples = samples;
                    self.tableView.reloadData()
                }
            } else {
                print("got no samples back")
            }
        }
        healthStore.execute(sampleQuery)
    }
    
    func addBloodGlucoseReading(_ when: String!, notes: String!, reading: Double) {
        // check for presence of HealthKit with optional binding statement
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if let healthStore = appDelegate.healthStore {
            let now = Date()
            let bloodGlucoseType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)
            let bloodGlucoseQuantity = HKQuantity(unit: bloodGlucoseUnit, doubleValue: reading)
            var meta = [String: Any]()
            if let bloodGlucoseWhen = when {
                meta[myHKMetadataKeyBloodGlucoseWhen] = bloodGlucoseWhen
            }
            if let bloodGlucoseNotes = notes {
                meta[myHKMetadataKeyBloodGlucoseNotes] = bloodGlucoseNotes
            }
            
            let bloodGlucoseSample = HKQuantitySample(type: bloodGlucoseType!, quantity: bloodGlucoseQuantity, start: now, end: now, metadata: meta)
            
            healthStore.save(bloodGlucoseSample) {
                (success: Bool, error: Error?) in
                if success {
                    print("successfully saved blood glucose reading to HealthKit")
                } else if let theError = error {
                    print("error saving blood glucose reading to HealthKit = \(theError)")
                }
                DispatchQueue.main.async {
                    if self.bloodGlucoseSamples == nil {
                        self.bloodGlucoseSamples = []
                    }
                    self.bloodGlucoseSamples?.insert(bloodGlucoseSample, at: 0)
                    print("bloodGlucoseSamples = \(self.bloodGlucoseSamples?.count)")
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    // MARK: UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var rows = 0;
        if let samples = bloodGlucoseSamples {
            rows = samples.count
        }
        return rows
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        let cell = tableView.dequeueReusableCell(withIdentifier: kBloodGlucoseCellIdentifier) ?? UITableViewCell(style: UITableViewCellStyle.subtitle, reuseIdentifier: kBloodGlucoseCellIdentifier)

        // we shouldn't get here unless _bloodGlucoseSamples is valid so "force" unwrap
        let sample = bloodGlucoseSamples![row] as! HKQuantitySample
        
        var valueText = ""
        var whenText = ""
        // retreve value from sample
        let value = Int(sample.quantity.doubleValue(for: self.bloodGlucoseUnit))
        valueText = String(value) + bloodGlucoseUnitString
        // retrieve the start date
        whenText += DateFormatter.localizedString(from: sample.startDate, dateStyle: DateFormatter.Style.short, timeStyle: DateFormatter.Style.short)
    
        // retrieve meta data from sample - when
        if let meta = sample.metadata {
            // notice syntax below optional form of type cast.  We need this since metadata is optional
            if let when = meta[myHKMetadataKeyBloodGlucoseWhen] as? String {
                whenText += " (\(when))"
            }
        }
       // populate the cell
        cell.textLabel?.text = valueText
        cell.detailTextLabel?.text = whenText
        
        return cell
    }
    
    // MARK: UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
    
    // MARK: Action Handlers
    
    @IBAction func clickedAdd(_ sender: AnyObject) {
        addBloodGlucoseReading(myHKMetadataValueBloodGlucoseWhenPostMeal, notes: nil, reading: 84)
    }
}
