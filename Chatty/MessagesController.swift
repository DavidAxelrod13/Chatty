//
//  ViewController.swift
//  Chatty
//
//  Created by David on 09/09/2017.
//  Copyright © 2017 David. All rights reserved.
//

import UIKit
import Firebase


class MessagesController: UITableViewController {
    
    let cellId = "cellId"
    
    lazy var logoutBarButton: UIBarButtonItem = {
        let logoutImage = UIImage(named: "logoutButton")
        let logoutImageFrame = CGRect(x: 0, y: 0, width: 44, height: 44)
        let logoutButton = UIButton(frame: logoutImageFrame)
        logoutButton.setImage(logoutImage, for: .normal)
        logoutButton.addTarget(self, action: #selector(handleLogout), for: .touchUpInside)
        let logoutBarButton = UIBarButtonItem(customView: logoutButton)
        return logoutBarButton
    }()
    
    lazy var createChatBarButton: UIBarButtonItem = {
        let createChatImage = UIImage(named: "messageButton")
        let createChatImageFrame = CGRect(x: 0, y: 0, width: 44, height: 44)
        let createChatButton = UIButton(frame: createChatImageFrame)
        createChatButton.setImage(createChatImage, for: .normal)
        createChatButton.addTarget(self, action: #selector(handleNewMessage), for: .touchUpInside)
        let createChatBarButton = UIBarButtonItem(customView: createChatButton)
        return createChatBarButton
    }()
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        navigationItem.leftBarButtonItem = logoutBarButton
        
        navigationItem.rightBarButtonItem = createChatBarButton
        // need to do this when working with cells withoug SB
        tableView.register(UserCell.self, forCellReuseIdentifier: cellId)
        
        checkIfUserIsLoggedIn()
                
        tableView.allowsMultipleSelectionDuringEditing = true
    }
    
    var messages = [Message]()
    var messagesDict = [String : Message]()
    
    
    func observeUserMessages() {
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return
        }
        // print(currentUserId)
        
        let ref = Database.database().reference().child("user-messages").child(currentUserId)
        
        ref.observe(.childAdded, with: { (snapshot) in
            
            let userId = snapshot.key
            Database.database().reference().child("user-messages").child(currentUserId).child(userId).observe(.childAdded, with: { (snapshot) in
                
                // this snapshot contains a message Id, for our user
                let messageId = snapshot.key
                self.fetchMessageWithMessageId(messageId: messageId)
                
            })
        })
        
        ref.observe(.childRemoved, with: { (snapshot) in
            
            self.messagesDict.removeValue(forKey: snapshot.key)
            self.attemptReloadOfTableData()
        })
    }
    
    private func fetchMessageWithMessageId(messageId: String) {
        
        let messageRef = Database.database().reference().child("messages").child(messageId)
        
        messageRef.observeSingleEvent(of: .value, with: { (snapshot) in
            
            if let dict = snapshot.value as? [String: AnyObject] {
                
                let message = Message(dict: dict)
                
                if let chatPartnerId = message.chatPartnerId() {
                    self.messagesDict[chatPartnerId] = message
                }
                
                self.attemptReloadOfTableData()
            }
            
        })
    }
    
    private func attemptReloadOfTableData() {
        
        self.timer?.invalidate()
        
        self.timer = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(self.handleReloadTable), userInfo: nil, repeats: false)
    }
    
    var timer:Timer?
    
    @objc func handleReloadTable() {
        
        self.messages = Array(self.messagesDict.values)
        
        if self.messages.count > 1 {
            self.messages.sort(by: { (message1, message2) -> Bool in
                
                return (message1.timeStamp?.intValue)! > (message2.timeStamp?.intValue)!
            })
        }
        
        DispatchQueue.main.async {
           // print("table has been reloaded")
            self.tableView.reloadData()
            
        }

    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let message = messages[indexPath.row]
        
        guard let chatPartnerId = message.chatPartnerId() else {
            return
        }
        
        let ref = Database.database().reference().child("users").child(chatPartnerId)
        
        ref.observeSingleEvent(of: .value, with: { (snapshot) in
            
            guard let dict = snapshot.value as? [String:AnyObject] else {
                return
            }
            
            let user = User(dictionary: dict)
            user.id = chatPartnerId
//            user.setValuesForKeys(dict)
            self.showChatControllerForUser(user: user)
        })
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! UserCell
        
        let message = messages[indexPath.row]
        
        cell.message = message
        
        return cell
        
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return
        }
        
        let chosenMessage = messages[indexPath.row]
        
        if let chatPartnerId = chosenMessage.chatPartnerId() {
            Database.database().reference().child("user-messages").child(currentUserId).child(chatPartnerId).removeValue(completionBlock: { (error, ref) in
                
                if error != nil {
                    print("Failed to delete the message", error!.localizedDescription)
                    return
                }
                
                self.messagesDict.removeValue(forKey: chatPartnerId)
                self.attemptReloadOfTableData()
            })
        }
    }
    
    @objc func handleNewMessage() {
        
        let newMessageVC = NewMessageTVController()
        newMessageVC.messagesController = self
        let navController = UINavigationController(rootViewController: newMessageVC)
        present(navController, animated: true, completion: nil)
        
    }
    
    func checkIfUserIsLoggedIn() {
        
        if Auth.auth().currentUser?.uid == nil {
            // the user is not logged in
            perform(#selector(handleLogout), with: nil, afterDelay: 0)
        } else {
            
            fetchUserAndSetupNavBarTitle()
        }
    }
    
    func fetchUserAndSetupNavBarTitle() {
        
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        Database.database().reference().child("users").child(uid).observeSingleEvent(of: .value, with: { (snapshot) in
            //print(snapshot)
            if let dict = snapshot.value as? [String:AnyObject] {
                
                let user = User(dictionary: dict)
                self.setupNavBarWithUser(user: user)
            }
        })
    }
    
    func setupNavBarWithUser(user: User) {
        
        messages.removeAll()
        messagesDict.removeAll()
        tableView.reloadData()
        
        observeUserMessages()

        
        let titleView = UIView()
        titleView.frame = CGRect(x: 0, y: 0, width: 100, height: 40)
//        titleView.backgroundColor = UIColor.red
        
        let contenView = UIView()
        contenView.translatesAutoresizingMaskIntoConstraints = false
        titleView.addSubview(contenView)
        
        let profileImageView = UIImageView()
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.layer.cornerRadius = 20
        profileImageView.clipsToBounds = true
        if let profileImageUrl = user.profileImageUrl {
            profileImageView.loadImageUsingCacheWithUrlString(urlString: profileImageUrl)
        }
        
        contenView.addSubview(profileImageView)
        
        // x,y,width and height anchors 
        profileImageView.leftAnchor.constraint(equalTo: contenView.leftAnchor).isActive = true
        profileImageView.centerYAnchor.constraint(equalTo: contenView.centerYAnchor).isActive = true
        profileImageView.heightAnchor.constraint(equalToConstant: 40).isActive = true
        profileImageView.widthAnchor.constraint(equalToConstant: 40).isActive = true
        
        
        let nameLabel = UILabel()
        
        contenView.addSubview(nameLabel)

        nameLabel.text = user.name
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // x,y,width and height anchors
        nameLabel.leftAnchor.constraint(equalTo: profileImageView.rightAnchor, constant: 8).isActive = true
        nameLabel.centerYAnchor.constraint(equalTo: profileImageView.centerYAnchor).isActive = true
        nameLabel.rightAnchor.constraint(equalTo: contenView.rightAnchor).isActive = true
        nameLabel.heightAnchor.constraint(equalTo: profileImageView.heightAnchor).isActive = true
        
        contenView.centerXAnchor.constraint(equalTo: titleView.centerXAnchor).isActive = true
        contenView.centerYAnchor.constraint(equalTo: titleView.centerYAnchor).isActive = true
        
        self.navigationItem.titleView = titleView
        
   //     titleView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showChatController)))
        
    }
    
    func showChatControllerForUser(user: User) {
        
        let chatLogController = ChatLogController(collectionViewLayout: UICollectionViewFlowLayout())
        chatLogController.user = user
        navigationController?.pushViewController(chatLogController, animated: true)
        
    }

    @objc func handleLogout() {
        do {
            try Auth.auth().signOut()
        } catch let logoutError {
           print(logoutError.localizedDescription)
        }
        
        
        let loginVc = LoginVC()
        loginVc.messagesController = self
        present(loginVc, animated: true, completion: nil)
    }

}

