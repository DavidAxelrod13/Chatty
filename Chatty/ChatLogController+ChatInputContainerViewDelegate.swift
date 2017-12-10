//
//  ChatLogController+ChatInputContainerDelegate.swift
//  Chatty
//
//  Created by David on 31/10/2017.
//  Copyright © 2017 David. All rights reserved.
//

import UIKit

extension ChatLogController: ChatInputContainerViewDelegate {
    func didTapOnSendButton() {
        handleSend()
    }
    
    func didTapOnSelectMediaButton() {
        handleImageButtonTap()
    }    
}
