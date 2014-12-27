//
//  SwiftChatViewContoller.swift
//  SwiftChat
//
//  Created by kimiyash on 2014/12/27.
//  Copyright (c) 2014年 kimiyash. All rights reserved.
//

import UIKit

class SwiftChatViewContoller: SOMessagingViewController {
    let dataSource = NSMutableArray()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let msg = Message()
        msg.fromMe = true
        msg.text = "hoge"
        msg.type = SOMessageTypeText
        msg.date = NSDate()
        self.dataSource.addObject(msg)
        
    }
    
    override func viewDidAppear(animated: Bool) {
        // Do any additional setup after loading the view, typically from a nib.
        if PFUser.currentUser() == nil {
            self.loginOrSignup()
        } else {
            self.loadMessages()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    // MARK: - SOMessaging data source
    override func messages() -> NSMutableArray! {
        return self.dataSource
    }

    override func intervalForMessagesGrouping() -> NSTimeInterval {
        // Return 0 for disableing grouping
        return 2 * 24 * 3600;
    }
    
    override func configureMessageCell(cell: SOMessageCell!, forMessageAtIndex index: Int) {
        let message = self.dataSource[index] as Message
        
        if (!message.fromMe) {
            cell.contentInsets = UIEdgeInsetsMake(0, 3.0, 0, 0)
            cell.textView.textColor = UIColor.blackColor()
        } else {
            cell.contentInsets = UIEdgeInsetsMake(0, 0, 0, 3.0)
            cell.textView.textColor = UIColor.blackColor()
        }
        
        cell.userImageView.layer.cornerRadius = self.userImageSize().width/2;

    }
    

    override func messageMaxWidth() -> CGFloat {
        return 140
    }
    
    override func userImageSize() -> CGSize {
        return CGSizeMake(40, 40)
    }
    
    // MARK: - SOMessaging delegate
    override func didSelectMedia(media: NSData!, inMessageCell cell: SOMessageCell!) {
        super.didSelectMedia(media, inMessageCell: cell)
    }
    
    override func messageInputView(inputView: SOMessageInputView!, didSendMessage message: String!) {
        if 0 == countElements(message.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())) {
            return
        }
        
        let msg = Message()
        msg.text = message
        msg.fromMe = true

        let message: PFObject = PFObject(className: "Messages")
        message["text"] = msg.text
        message["user"] = PFUser.currentUser()
        message.saveInBackgroundWithBlock{
            (success :Bool, error :NSError!) -> Void in
            if error == nil {
                println("Send text successful")
            } else {
                let errorString = error.userInfo?["error"] as NSString
                println(errorString)
            }
        }
        
        self.sendMessage(msg)
    }
    
    
    // MARK: - private methods
    func loginOrSignup() {
        let loginAlert:UIAlertController = UIAlertController(title: "Sign UP / Loign", message: "Plase sign up or login", preferredStyle: UIAlertControllerStyle.Alert)
        
        loginAlert.addTextFieldWithConfigurationHandler({
            textfield in
            textfield.placeholder = "Your username"
        })
        
        loginAlert.addTextFieldWithConfigurationHandler({
            textfield in
            textfield.placeholder = "Your Password"
            textfield.secureTextEntry = true
        })
        
        loginAlert.addAction(UIAlertAction(title: "Login", style: UIAlertActionStyle.Default, handler: {
            alertAction in
            let textFields = loginAlert.textFields as NSArray?
            let usernameTextfield = textFields?.objectAtIndex(0) as UITextField
            let passwordTextfield = textFields?.objectAtIndex(1) as UITextField
            
            let user = PFUser()
            user.username = usernameTextfield.text
            user.password = passwordTextfield.text
            
            user.signUpInBackgroundWithBlock{
                (success: Bool, error: NSError!) -> Void in
                if error == nil {
                    println("Sign up successful")
                    self.loadMessages()
                } else {
                    let errorString = error.userInfo?["error"] as NSString
                    println(errorString)
                }
            }
            
        }))
        
        self.presentViewController(loginAlert, animated: true, completion: nil)
    }
    
    func loadMessages() {
        let findTimelineData = PFQuery(className: "Messages")
        findTimelineData.findObjectsInBackgroundWithBlock{
            (messages :[AnyObject]!, error :NSError!)->Void in
            if error == nil {
                for message in messages {
                    self.appendDataSource(message as PFObject)
                }
                dispatch_async(dispatch_get_main_queue(),{
                    self.refreshMessages()
                    NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: Selector("pollingMessage"), userInfo: nil, repeats: true)
                })
            }
        }
    }
    
    func pollingMessage() {
        let findTimelineData = PFQuery(className: "Messages")
        findTimelineData.findObjectsInBackgroundWithBlock{
            (messages :[AnyObject]!, error :NSError!)->Void in
            if error == nil {
                var count = 0
                var isAppend = false
                for message in messages {
                    if ++count > self.dataSource.count - 1 {
                        self.appendDataSource(message as PFObject)
                        isAppend = true
                    }
                }
                if isAppend {
                    dispatch_async(dispatch_get_main_queue(),{ self.refreshMessages() })
                }
            }
        }
    }
    
    func appendDataSource(message :PFObject) {
        let msg = Message()
        msg.fromMe = PFUser.currentUser().objectId == (message["user"] as PFUser).objectId
        msg.text = message["text"] as String
        msg.type = SOMessageTypeText
        msg.date = message.createdAt
        self.dataSource.addObject(msg)
    }

}

