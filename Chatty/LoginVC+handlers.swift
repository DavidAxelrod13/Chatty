//
//  LoginVC+handlers.swift
//  Chatty
//
//  Created by David on 10/09/2017.
//  Copyright © 2017 David. All rights reserved.
//

import UIKit
import Firebase

extension LoginVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        
    func handleRegister() {
        
        guard let email = emailTextField.text, let password = passwordTextField.text, let name = nameTextField.text else {
            print("Invalid Form")
            return }
        
        Auth.auth().createUser(withEmail: email, password: password) { (user, error) in
            
            if error != nil {
                print(error!.localizedDescription)
                return
            }
            guard let uid = user?.uid else { return }
            // successfully authenticated the user
            // give a unique id to store images under
            let imageName = NSUUID().uuidString
            let storageRef = Storage.storage().reference().child("profile_images").child("\(imageName).jpg")
            
            if let profileImage = self.profileImageView.image, let uploadData =  UIImageJPEGRepresentation(profileImage, 0.1) {

//            if let uploadData = UIImagePNGRepresentation(self.profileImageView.image!) {
                
                storageRef.putData(uploadData, metadata: nil, completion: { (metadata, error) in
                    
                    if error != nil {
                        print(error!.localizedDescription)
                        return
                    }
                    // successfully uploaded the profile image into Storage
                    if let profileImageUrl = metadata?.downloadURL()?.absoluteString {
                        
                        let values = ["name" : name, "email" : email, "profileImageUrl" : profileImageUrl]
                        
                        self.registerUserIntoDatabaseWithUID(uid: uid, values: values as [String : AnyObject])
                    }

                })
            }
        }
    }
    
    
    private func registerUserIntoDatabaseWithUID(uid: String, values: [String : AnyObject]) {
        
        // save the user in our FD DB users table under his unique iD from the FB Authentication process
        let ref = Database.database().reference()
        let usersRef = ref.child("users").child(uid)
        usersRef.setValue(values, withCompletionBlock: { (err, ref) in
            
            if err != nil {
                print(err!.localizedDescription)
                return
            }
            
            let user = User(dictionary: values)
            self.messagesController?.setupNavBarWithUser(user: user)
            
            print("Saved user successfully into FB DB")
            self.dismiss(animated: true, completion: nil)
        })

    }

    @objc func handleSelectProfileImageView() {
        
        
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true, completion: nil)
        
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        
        print("cancelled picker")
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        let selectedImage = info[UIImagePickerControllerEditedImage] as? UIImage
            
        if let selectedImage = selectedImage {
            
            profileImageView.image = selectedImage
        }
        
        dismiss(animated: true, completion: nil)
        
    }
    
}
