//
//  ChatInputContainerView.swift
//  Chatty
//
//  Created by David on 14/09/2017.
//  Copyright © 2017 David. All rights reserved.
//

import UIKit

protocol ChatInputContainerViewDelegate: class {
    func didTapOnSendButton() -> ()
    func didTapOnSelectMediaButton() -> ()
}

class ChatInputContainerView: UIView, UITextFieldDelegate {

    weak var delegate: ChatInputContainerViewDelegate? {
        didSet {
            sendButton.addTarget(self, action: #selector(handleSendButtonTap), for: .touchUpInside)
            uploadImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleMediaSelectionButtonTap)))
        }
    }
    
    let uploadImageView: UIImageView = {
        let uploadImageView = UIImageView()
        uploadImageView.isUserInteractionEnabled = true
        uploadImageView.image = UIImage(named: "imageBut")
        uploadImageView.translatesAutoresizingMaskIntoConstraints = false
        return uploadImageView
    }()
    
    let sendButton = UIButton(type: .system)
    
    lazy var inputTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Enter message..."
        textField.backgroundColor = UIColor.white
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        return textField
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = UIColor.white
        
    
        addSubview(uploadImageView)
        
        // x,y, width and height constraints
        uploadImageView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        uploadImageView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        uploadImageView.widthAnchor.constraint(equalToConstant: 44).isActive = true
        uploadImageView.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        
        sendButton.setTitle("Send", for: .normal)
        sendButton.backgroundColor = UIColor.white
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(sendButton)
        
        // x,y, width and height constraints
        sendButton.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        sendButton.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        sendButton.widthAnchor.constraint(equalToConstant: 80).isActive = true
        sendButton.heightAnchor.constraint(equalTo: heightAnchor).isActive = true
        
        
        addSubview(self.inputTextField)
        
        // x,y, width and height constraints
        self.inputTextField.leftAnchor.constraint(equalTo: uploadImageView.rightAnchor, constant: 8).isActive = true
        self.inputTextField.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        self.inputTextField.rightAnchor.constraint(equalTo: sendButton.leftAnchor).isActive = true
        self.inputTextField.heightAnchor.constraint(equalTo: heightAnchor).isActive = true
        
        let seperatorLineView = UIView()
        seperatorLineView.backgroundColor = UIColor(r: 220, g: 220, b: 220)
        seperatorLineView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(seperatorLineView)
        
        // x,y, width and height constraints
        seperatorLineView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        seperatorLineView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        seperatorLineView.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        seperatorLineView.heightAnchor.constraint(equalToConstant: 0.7).isActive = true
        
    }
    
    @objc private func handleSendButtonTap() {
        delegate?.didTapOnSendButton()
    }
    
    @objc private func handleMediaSelectionButtonTap() {
        delegate?.didTapOnSelectMediaButton()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        delegate?.didTapOnSendButton()
        return true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
