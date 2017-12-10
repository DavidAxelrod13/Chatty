//
//  ChatLogController.swift
//  Chatty
//
//  Created by David on 10/09/2017.
//  Copyright © 2017 David. All rights reserved.
//

import UIKit
import Firebase
import MobileCoreServices
import AVFoundation

class ChatLogController: UICollectionViewController, UITextFieldDelegate, UICollectionViewDelegateFlowLayout, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    let cellId = "cellId"
    
    var user: User? {
        didSet {
           
            navigationItem.title = user?.name
            
            observeMessages()
        }
    }
    
    var messages = [Message]()
    
    func observeMessages() {
        
        guard let currentUserId = Auth.auth().currentUser?.uid, let partnerUserId = user?.id else {
            return
        }
        
        let ref = Database.database().reference().child("user-messages").child(currentUserId).child(partnerUserId)
        
        ref.observe(.childAdded, with: { (snapshot) in
            
            let messageId = snapshot.key
            let messagesRef = Database.database().reference().child("messages").child(messageId)
            
            messagesRef.observeSingleEvent(of: .value, with: { (snapshot) in
                
                guard let dict = snapshot.value as? [String:AnyObject] else {
                    return
                }
                
                let message = Message(dict: dict)

                self.messages.append(message)
                DispatchQueue.main.async {
                    self.collectionView?.reloadData()
                    // scroll to the last message
                    if self.messages.count > 0 {
                    let indexPath = IndexPath(item: self.messages.count - 1, section: 0)
                        if (self.indexPathIsValid(indexPath: indexPath)) {
                            self.collectionView?.scrollToItem(at: indexPath, at: .bottom, animated: true)
                        }
                    }
                }
                
            })
        })
    
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView?.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        
        collectionView?.alwaysBounceVertical = true
        collectionView?.backgroundColor = UIColor.white
        collectionView?.register(ChatMessageCell.self, forCellWithReuseIdentifier: cellId)
        
        collectionView?.keyboardDismissMode = .interactive
        
        setupKeyboardObservers()
    }
    
    lazy var inputContainerView: ChatInputContainerView = {
        
        let chatLogInputContainerView = ChatInputContainerView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: 50))
        
        chatLogInputContainerView.delegate = self

        return chatLogInputContainerView
    }()
    
    override var inputAccessoryView: UIView? {
        get{
            return inputContainerView
        }
    }
    
    @objc func handleImageButtonTap() {
        
        let imagePickerController = UIImagePickerController()
        
        imagePickerController.delegate = self
        imagePickerController.allowsEditing = true
        imagePickerController.mediaTypes = [kUTTypeImage as String, kUTTypeMovie as String]
        
        present(imagePickerController, animated: true, completion: nil)
    
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        if let videoUrl = info[UIImagePickerControllerMediaURL] as? URL {
            // we selected a video
            
            handleVideoSelectedForUrl(url: videoUrl)
        } else {
            // we selected an image
            
            handleImageSelectedForInfo(info: info)
        }
        
        dismiss(animated: true, completion: nil)

    }
    
    private func handleVideoSelectedForUrl(url: URL) {
        
        let videoName = UUID().uuidString + ".mov"
        
        let uploadTask = Storage.storage().reference().child("message_videos").child(videoName).putFile(from: url, metadata: nil, completion: { (metadata, error) in
            
            if error != nil {
                print("Failed upload of video", error!.localizedDescription)
                return
            }
            
            if let videoUrl = metadata?.downloadURL()?.absoluteString {
                
                if let thumbnailImage = self.thumbnailImageFoFilerUrl(fileUrl: url) {
                    
                    self.uploadImageToFirebaseStorage(image: thumbnailImage, completion: { (imageUrl) in
                        
                        let properties = ["imageUrl" : imageUrl, "imageWidth" : thumbnailImage.size.width, "imageHeight" : thumbnailImage.size.height, "videoUrl": videoUrl as AnyObject] as [String : AnyObject]
                        self.sendMessageWithProperties(properties: properties)
                    })
                }
            }
        })
        
        uploadTask.observe(.progress) { (snapshot) in
            if let completedUnitCount = snapshot.progress?.completedUnitCount, let totalUnitCount = snapshot.progress?.totalUnitCount {
                let uploadPercentage = (Float64(completedUnitCount)/Float64(totalUnitCount)) * 100
                let stringPercentage = String(format: "%.0f", uploadPercentage) + " %"
                print(stringPercentage)
                self.navigationItem.title = stringPercentage
            }
        }
        
        uploadTask.observe(.success) { (snapshot) in
            self.navigationItem.title = self.user?.name
        }
    }
    
    private func thumbnailImageFoFilerUrl(fileUrl: URL) -> UIImage? {
        
        let asset = AVAsset(url: fileUrl)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        do {
            
             let thumbnailCgImage = try imageGenerator.copyCGImage(at: CMTimeMake(1, 60), actualTime: nil)
            return UIImage(cgImage: thumbnailCgImage)
            
        } catch let err {
            print(err)
        }
       
        return nil
    }
    
    private func handleImageSelectedForInfo(info: [String: Any]) {
        
        let selectedImage = info[UIImagePickerControllerEditedImage] as? UIImage
        
        if let selectedImage = selectedImage {
            // we have an image + we need to upload it to FB Storage
            uploadImageToFirebaseStorage(image: selectedImage, completion: { (imageUrl) in
                self.sendMessageWithImageUrl(imageUrl: imageUrl, image: selectedImage)
            })
        }

    }
    
    private func uploadImageToFirebaseStorage(image: UIImage, completion: @escaping (_ imageUrl: String) -> ()) {
        
        let imageName = UUID().uuidString
        
        let ref = Storage.storage().reference().child("message_images").child(imageName)
        
        if let uploadData = UIImageJPEGRepresentation(image, 0.2) {
            ref.putData(uploadData, metadata: nil, completion: { (metadata, error) in
                
                if error != nil {
                    print("Failed to upload Image", error!.localizedDescription)
                    return
                }
                
                // have successfully uploaded the image to Storage
                
                if let imageUrl = metadata?.downloadURL()?.absoluteString {
                    // we now have a download string for the image
                    completion(imageUrl)
                }
            })
        }
    }
    
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    

    override var canBecomeFirstResponder: Bool { return true }

    
    func setupKeyboardObservers() {
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardDidShow), name: .UIKeyboardDidShow, object: nil)
        
    }
    
    @objc func handleKeyboardDidShow() {
        if messages.count > 0 {
            let indexPath = IndexPath(item: self.messages.count - 1, section: 0)
            if (indexPathIsValid(indexPath: indexPath)) {
                collectionView?.scrollToItem(at: indexPath, at: .top, animated: true)
            }
        }
    }
    
    func indexPathIsValid(indexPath: IndexPath) -> Bool {
        if indexPath.section >= (collectionView?.numberOfSections)! {
            return false
        }
        
        if indexPath.row >= (collectionView?.numberOfItems(inSection: 0))! {
            return false
        }
        
        return true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return messages.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! ChatMessageCell
        
        cell.chatLogController = self
        
        let message = messages[indexPath.item]
        cell.message = message
            
        cell.textView.text = message.text
        
        setupCell(cell: cell, message: message)
        
        // modify cells width
        if let text = message.text {
            // text message
            cell.bubbleWidthAnchor?.constant = estimatedFrameForText(text: text).width + 32
            cell.textView.isHidden = false
        } else if message.imageUrl != nil {
            // fall in here if its image message 
            cell.bubbleWidthAnchor?.constant = 200
            cell.textView.isHidden = true 
        }
        // if ther is no videoUrl, then its not a video, then we hide play button 
        cell.videoPlayButton.isHidden = message.videoUrl == nil
        
        return cell
    }
    
    private func setupCell(cell: ChatMessageCell, message: Message) {
        
        if let profileImageUrl = self.user?.profileImageUrl {
            cell.profileImageView.loadImageUsingCacheWithUrlString(urlString: profileImageUrl)
        }
        
        if message.fromUserId == Auth.auth().currentUser?.uid {
            // outgoing case -> blue bubbles
            cell.bubbleView.backgroundColor = ChatMessageCell.blueColour
            cell.textView.textColor = UIColor.white
            cell.profileImageView.isHidden = true
            
            cell.bubbleViewRightAnchor?.isActive = true
            cell.bubbleViewLeftAnchor?.isActive = false
        } else {
            // incomming case -> grey bubbles
            cell.bubbleView.backgroundColor = UIColor(r: 240, g: 240, b: 240)
            cell.textView.textColor = UIColor.black
            cell.profileImageView.isHidden = false
            
            cell.bubbleViewRightAnchor?.isActive = false
            cell.bubbleViewLeftAnchor?.isActive = true
        }
        
        if let messageImageUrl = message.imageUrl {
            cell.messageImageView.loadImageUsingCacheWithUrlString(urlString: messageImageUrl)
            cell.messageImageView.isHidden = false
            cell.bubbleView.backgroundColor = UIColor.clear
        } else {
            cell.messageImageView.isHidden = true
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        
        collectionView?.collectionViewLayout.invalidateLayout()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        var height: CGFloat = 80
        
        let message = messages[indexPath.item]
        
        if let text = message.text {
            height = estimatedFrameForText(text: text).height + 20
            
        } else if let imageWidth = message.imageWidth?.floatValue, let imageHeight = message.imageHeigh?.floatValue {
            
            height = CGFloat(imageHeight / imageWidth * 200)
            //print("IMAGE HEIGHT: \(height)")
            
        }
        
        let width = UIScreen.main.bounds.width
        
        return CGSize(width: width, height: height)
    }
    
    private func estimatedFrameForText(text: String) -> CGRect {
        
        let size = CGSize(width: 200, height: 2000)
        let options = NSStringDrawingOptions.usesFontLeading.union(.usesLineFragmentOrigin)
        
        return NSString(string: text).boundingRect(with: size, options: options, attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 16)], context: nil)
        
    }
    
    var containerViewBottomAnchor: NSLayoutConstraint?
    
    @objc func handleSend() {
        
        let inputString = inputContainerView.inputTextField.text
        
        if (inputString?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? "").isEmpty {
            print("String is nil or empty")
        } else {
            let properties = ["text" : inputContainerView.inputTextField.text!] as [String : AnyObject]
            sendMessageWithProperties(properties: properties)
        }
    }
    
    
    private func sendMessageWithImageUrl(imageUrl: String, image: UIImage) {
        
        let properties = ["imageUrl" : imageUrl, "imageWidth" : image.size.width, "imageHeight" : image.size.height] as [String : AnyObject]
        sendMessageWithProperties(properties: properties)
    }
    
    private func sendMessageWithProperties(properties: [String:AnyObject]) {
        
        let ref = Database.database().reference().child("messages")
        let childRef = ref.childByAutoId()
        // the unique id of the user that the message is going to
        let toUserId = user!.id!
        let fromUserId = Auth.auth().currentUser!.uid
        // number of secotnd
        let timeStamp = Int(NSDate().timeIntervalSince1970)
        
        var values = ["fromUserId" : fromUserId, "toUserId" : toUserId, "timeStamp" : timeStamp] as [String : AnyObject]
        
        // appending the properties dict to values dict, $0 is the key, $1 is the value for the key
        properties.forEach({values[$0] = $1})
        
        // save the message in Messages
        childRef.updateChildValues(values) { (error, ref) in
            
            if error != nil {
                print(error!.localizedDescription)
                return
            }
            
            // if message saved successfully
            self.inputContainerView.inputTextField.text = nil
            
            // this is for outgoing
            let userRef = Database.database().reference().child("user-messages").child(fromUserId).child(toUserId)
            
            // get the rereference to the message (.key gets the last token in the FB DB location)
            let messageId = childRef.key
            userRef.updateChildValues([messageId : 1])
            
            // this is for incoming for the other user
            let recipientUserMessageId = Database.database().reference().child("user-messages").child(toUserId).child(fromUserId)
            recipientUserMessageId.updateChildValues([messageId : 1])
            
        }
    }
    
    
    var startingFrame: CGRect?
    var blackBackgroundView: UIView?
    var startingImageView: UIImageView?
    
    //MARK: - my custom zooming logic
    func performZoomInForStartingImageView(startingImageView: UIImageView) {

        self.startingImageView = startingImageView
        
        startingFrame = startingImageView.superview?.convert(startingImageView.frame, to: nil)
        
        let zoomingImageView = UIImageView(frame: startingFrame!)
        zoomingImageView.backgroundColor = UIColor.red
        zoomingImageView.image = startingImageView.image
        zoomingImageView.isUserInteractionEnabled = true
        zoomingImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleZoomOut)))
        
        if let keyWindow = UIApplication.shared.keyWindow {
            blackBackgroundView = UIView(frame: keyWindow.frame)
            blackBackgroundView?.backgroundColor = UIColor.black
            blackBackgroundView?.alpha = 0
            keyWindow.addSubview(blackBackgroundView!)
            keyWindow.addSubview(zoomingImageView)
            
            
            
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
                
                self.blackBackgroundView?.alpha = 1
                self.inputContainerView.alpha = 0
                self.startingImageView?.isHidden = true
                
                // height1 / width1 = height2 / width2
                let height = self.startingFrame!.height / self.startingFrame!.width * keyWindow.frame.width
                
                zoomingImageView.frame = CGRect(x: 0, y: 0, width: keyWindow.frame.width, height: height)
                
                zoomingImageView.center = keyWindow.center
                
                
                
            }, completion: { (completed: Bool) in
                    // do nothing
            })

            
        }
    }
    
    @objc func handleZoomOut(tapGesture: UITapGestureRecognizer) {
        
        if let zoomOutImageView = tapGesture.view {
            
            zoomOutImageView.layer.cornerRadius = 16
            zoomOutImageView.clipsToBounds = true
            
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: { 
                
                zoomOutImageView.frame = self.startingFrame!
                self.blackBackgroundView?.alpha = 0
                self.inputContainerView.alpha = 1

                
            }, completion: { (completed: Bool) in
                
                zoomOutImageView.removeFromSuperview()
                self.startingImageView?.isHidden = false
            })
        }
    }

}




