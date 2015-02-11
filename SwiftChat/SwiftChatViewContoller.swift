//
//  SwiftChatViewContoller.swift
//  SwiftChat
//
//  Created by kimiyash on 2014/12/27.
//  Copyright (c) 2014年 kimiyash. All rights reserved.
//

import UIKit

let kSwiftChatChanelName = "SwiftChat"

class SwiftChatViewContoller: SOMessagingViewController {
    
    let dataSource = NSMutableArray()
    let userImage = UIImage(named: "user-icon.jpg")
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "pullMessage:", name: kSwiftChatReceivedPushNotification, object: nil)

        self.dataSource.addObject(createTextMessage(true, text: "Welcome!", date: NSDate()))
    }
    
    override func viewDidAppear(animated: Bool) {
        if PFUser.currentUser() == nil {
            self.signup()
        } else {
            self.initialSetup()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
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
        
        cell.userImageView.autoresizingMask = message.fromMe ? UIViewAutoresizing.FlexibleLeftMargin
                                                             : UIViewAutoresizing.FlexibleBottomMargin
        
        cell.userImage = self.userImage
        
        self.generateUsernameLabelForCell(cell)
    }
    
    func generateUsernameLabelForCell(cell: SOMessageCell!) {
        let labelTag = NSInteger(666)
        
    }

    override func balloonImageForSending() -> UIImage? {
        let img = UIImage(named: "bubble_rect_sending.png");
        return img?.resizableImageWithCapInsets(UIEdgeInsetsMake(3, 3, 24, 11))
    }
    
    override func balloonImageForReceiving() -> UIImage? {
        let img = UIImage(named: "bubble_rect_receiving.png");
        return img?.resizableImageWithCapInsets(UIEdgeInsetsMake(3, 11, 24, 3))
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
                self.pushNotification(msg.text)
            } else {
                let errorString = error.userInfo?["error"] as NSString
                println(errorString)
            }
        }
        
        self.sendMessage(msg)
    }
    
    // MARK: - private methods
    func signup() {
        let signupAlert: UIAlertController = UIAlertController(title: "Signup", message: "Plase input your name", preferredStyle: UIAlertControllerStyle.Alert)
        
        signupAlert.addTextFieldWithConfigurationHandler({
            textfield in
            textfield.placeholder = "Your bame"
        })
        
        signupAlert.addAction(UIAlertAction(title: "Signup", style: UIAlertActionStyle.Default, handler: {
            alertAction in
            let textFields = signupAlert.textFields as NSArray?
            let usernameTextfield = textFields?.objectAtIndex(0) as UITextField
            
            let user = PFUser()
            user.username = usernameTextfield.text
            user.password = usernameTextfield.text
            
            user.signUpInBackgroundWithBlock{
                (success: Bool, error: NSError!) -> Void in
                if error == nil {
                    println("Sign up successful")
                    self.initialSetup()
                } else {
                    println(error.userInfo?["error"] as NSString)
                }
            }
            
        }))
        self.presentViewController(signupAlert, animated: true, completion: nil)
    }

    func pushNotification(msg: String!) {
        var push = PFPush()
        push.setChannel(kSwiftChatChanelName)
        push.setData(["alert": msg])
        push.sendPush(nil)
    }
    
    func initialSetup() {
        self.chanelSetup()
        self.loadMessages()
    }
    
    func chanelSetup() {
        var error = NSErrorPointer()
        PFPush.subscribeToChannel(kSwiftChatChanelName, error: error)
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
                    self.pullMessage(nil)
                })
            }
        }
    }
    
    func pullMessage(notification: NSNotification?) {
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
    
    func createTextMessage(fromMe: Bool, text: String, date: NSDate) -> Message {
        let msg = Message()
        msg.fromMe = fromMe
        msg.text = text
        msg.type = SOMessageTypeText
        msg.date = date
        return msg
    }
    
    func appendDataSource(message :PFObject) {
        let user = message["user"] as PFUser
        self.dataSource.addObject(self.createTextMessage(
            PFUser.currentUser().objectId == user.objectId,
            text: message["text"] as String,
            date: message.createdAt)
        )
    }

}

