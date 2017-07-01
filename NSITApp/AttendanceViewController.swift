//
//  AttendanceViewController.swift
//  NSITApp
//
//  Created by Manan Manwani on 29/06/17.
//  Copyright © 2017 Manan Manwani. All rights reserved.
//

import UIKit
import Firebase

class AttendanceViewController: UIViewController,UINavigationBarDelegate,UINavigationControllerDelegate,UITableViewDelegate,UITableViewDataSource {

    @IBOutlet weak var menu: UIBarButtonItem!
    
    @IBOutlet weak var tableView: UITableView!
    
    let databaseRef = Database.database().reference()
    
    var Subjects:Array = [String]()
    var SubjectRef:Array = [String]()

    
    override func viewDidLoad() {
        super.viewDidLoad()

        revealViewController().rearViewRevealWidth = 250
        menu.target = revealViewController()
        menu.action = #selector(SWRevealViewController.revealToggle(_:))
        
        
        let userReference = self.databaseRef.child("Syllabus").child("2nd Year").child("IT")
        
        //     let values = ["1":"1.png" , "2":"2.png" , "3":"3.png" , "4":"4.png" , "5":"5.png"]
        var values:NSDictionary = [:]
        
        userReference.observeSingleEvent(of: .value, with: { (snapshot) in
            // Get user value
            values = (snapshot.value as? NSDictionary)!
            self.Subjects = Array(values.allKeys) as! [String]
            self.SubjectRef = Array(values.allValues) as! [String]
            print(values)
            [self.tableView .reloadData()]
        }) { (error) in
            print(error.localizedDescription)
        }

    }

    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Subjects.count
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AttendanceTableViewCell", for: indexPath) as! AttendanceTableViewCell
        
        cell.subjectName.text! = Subjects[indexPath.row]
        cell.percentage.text! = "0%"
        
        return cell
    }
    
   /* func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let VC=UIStoryboard.init(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ShowSyllabusViewController") as! ShowSyllabusViewController
        
        VC.photoLink = SubjectRef[indexPath.row]
        
        self.present(VC, animated: true, completion: nil)
        
    }*/

}
