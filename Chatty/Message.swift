//
//  Message.swift
//  Chatty
//
//  Created by David on 11/09/2017.
//  Copyright © 2017 David. All rights reserved.
//

import UIKit
import Firebase

class Message: NSObject {

    
    var fromUserId: String?
    var text: String?
    var timeStamp: NSNumber?
    var toUserId: String?
    
    var imageUrl: String?
    var imageHeigh: NSNumber?
    var imageWidth: NSNumber?
    
    var videoUrl: String?
    
    func chatPartnerId() -> String? {
        
        if fromUserId == Auth.auth().currentUser?.uid {
            // this is for an outgoing message
            return toUserId
        } else {
            // this if for an incoming message
            return fromUserId
        }
    }
    
    init(dict: [String: AnyObject]) {
        super.init()
        
        fromUserId = dict["fromUserId"] as? String
        text = dict["text"] as? String
        timeStamp = dict["timeStamp"] as? NSNumber
        toUserId = dict["toUserId"] as? String
        
        imageUrl = dict["imageUrl"] as? String
        imageHeigh = dict["imageHeight"] as? NSNumber
        imageWidth = dict["imageWidth"] as? NSNumber

        videoUrl = dict["videoUrl"] as? String
    }
}
