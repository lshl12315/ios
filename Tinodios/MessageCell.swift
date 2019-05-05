//
//  MessageCell.swift
//  Tinodios
//
//  Created by Gene Sokolov on 03/05/2019.
//  Copyright © 2019 Tinode. All rights reserved.
//

import UIKit
import TinodeSDK

/// A protocol used to detect taps in the chat message.
protocol MessageCellDelegate: class {
    func didTapMessage(in cell: MessageCell)

    func didTapAvatar(in cell: MessageCell)
}

// Contains message bubble + avatar + delivery markers.
class MessageCell: UICollectionViewCell {

    // MARK: - Initializers

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.white
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        setupSubviews()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        backgroundColor = UIColor.white
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        setupSubviews()
    }

    /// The image view with the avatar.
    var avatarView: RoundImageView = RoundImageView()

    /// The UIImageView with background being the bubble,
    /// holds the message's content view.
    var containerView: UIImageView = {
        let view = UIImageView()
        view.clipsToBounds = true
        view.layer.masksToBounds = true
        return view
    }()

    /// The message content
    var content: PaddedLabel = {
        let content = PaddedLabel()
        // Indicates multiline content.
        content.numberOfLines = 0
        return content
    }()

    /// The label above the messageBubble which holds the date of conversation.
    var newDateLabel: PaddedLabel = {
        let label = PaddedLabel()
        label.textAlignment = .center
        return label
    }()

    /// The label under the messageBubble: sender's name in group topics.
    var senderNameLabel: PaddedLabel = {
        let label = PaddedLabel()
        label.textAlignment = .natural
        return label
    }()

    /// Delivery marker.
    var deliveryMarker: UIImageView = UIImageView()

    /// Message timestamp.
    var timestampLabel: PaddedLabel = PaddedLabel()

    /// The `MessageCellDelegate` for the cell.
    weak var delegate: MessageCellDelegate?

    func setupSubviews() {
        contentView.addSubview(newDateLabel)
        contentView.addSubview(senderNameLabel)
        contentView.addSubview(containerView)
        containerView.addSubview(content)
        // containerView.addSubview(deliveryMarker)
        // containerView.addSubview(timestampLabel)
        contentView.addSubview(avatarView)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        newDateLabel.text = nil
        senderNameLabel.text = nil
    }

    /// Handle tap gesture on contentView and its subviews.
    func handleTapGesture(_ gesture: UIGestureRecognizer) {
        let touchLocation = gesture.location(in: self)

        switch true {
        case containerView.frame.contains(touchLocation) && !cellContentView(canHandle: convert(touchLocation, to: containerView)):
            delegate?.didTapMessage(in: self)
        case avatarView.frame.contains(touchLocation):
            delegate?.didTapAvatar(in: self)
        default:
            break
        }
    }

    /// Handle long press gesture, return true when gestureRecognizer's touch point in `messageContainerView`'s frame
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let touchPoint = gestureRecognizer.location(in: self)
        guard gestureRecognizer.isKind(of: UILongPressGestureRecognizer.self) else { return false }
        return containerView.frame.contains(touchPoint)
    }

    /// Handle `ContentView`'s tap gesture, return false when `ContentView` doesn't needs to handle gesture
    func cellContentView(canHandle touchPoint: CGPoint) -> Bool {
        return false
    }
}

